"""Layer 2 — findings: schema coercion, URL normalisation, dedup/merge, add/list/resume-context."""
from __future__ import annotations

import re
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from .http import to_int
from .fs import err, now, read_jsonl, write_jsonl
from .model import GEO, GROUPS
from . import sessions

TRACKING_PARAMS = {"utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
                   "gclid", "fbclid", "yclid", "ref", "from"}
LIST_FIELDS = ("pros", "cons", "nuances", "review_sources")
INT_FIELDS = ("price_uah", "price_min_uah", "price_max_uah", "rating_count", "offers_count")
# Fields that a later observation of the same URL should overwrite (fresh price/stock beats stale).
REFRESH_FIELDS = ("price_uah", "price_min_uah", "price_max_uah", "price_note", "rating", "rating_count",
                  "offers_count", "availability", "installment", "installment_note", "seller",
                  "delivery_scope", "model_match", "url")


def defaults() -> dict:
    return {
        "id": None, "ts": None, "group": None, "source": "", "title": "", "model": "", "url": "",
        "price_uah": None, "price_min_uah": None, "price_max_uah": None, "price_note": "",
        "rating": None, "rating_count": None, "offers_count": None,
        "availability": "", "seller": "", "delivery_scope": "ua_local", "category": "",
        "installment": None, "installment_note": "",
        "pros": [], "cons": [], "nuances": [], "review_sources": [], "notes": "",
        "model_match": "",
    }


def normalize_url(url: str) -> str:
    try:
        u = urlsplit(url.strip())
    except ValueError:
        return url.strip()
    q = [(k, v) for k, v in parse_qsl(u.query, keep_blank_values=True) if k.lower() not in TRACKING_PARAMS]
    return urlunsplit((u.scheme.lower(), u.netloc.lower(), u.path.rstrip("/") or "/", urlencode(q), ""))


def normalize_model(model: str | None) -> str:
    """Spacing/dash/case-insensitive key; '+' spelled out so 'S25+' == 'S25 Plus'."""
    return re.sub(r"[\s\-_/]+", "", (model or "").upper().replace("+", "PLUS"))


def model_key(f: dict) -> str:
    return normalize_model(f.get("model")) or (f.get("title") or "").strip().upper()


def _dedupe_ci(items: list[str], base: list[str] | None = None) -> list[str]:
    """Case-insensitive, order-preserving union of base + items (empty strings dropped)."""
    out = list(base or [])
    seen = {x.lower() for x in out}
    for x in items:
        if x and x.lower() not in seen:
            seen.add(x.lower())
            out.append(x)
    return out


def coerce(raw: dict) -> tuple[dict | None, str | None]:
    f = defaults()
    unknown = [k for k in raw if k not in f]
    if unknown:
        return None, f"unknown finding fields {unknown}; allowed: {sorted(f)}"
    f.update(raw)
    if f["group"] not in GROUPS:
        return None, f"group must be one of {GROUPS}"
    if not f["url"]:
        return None, "url is required"
    if not f["title"] and not f["model"]:
        return None, "title or model is required"
    if f["delivery_scope"] not in GEO:
        return None, f"delivery_scope must be one of {GEO}"
    for k in LIST_FIELDS:
        v = f[k]
        if isinstance(v, str):
            v = re.split(r"[;\n]", v)
        f[k] = _dedupe_ci([str(x).strip() for x in (v or [])])
    for k in INT_FIELDS:
        if f[k] is not None:
            v = to_int(f[k])          # shared parser: '10796.55' → 10796, never 1079655
            if v is None:
                return None, f"{k} must be numeric"
            # a zero price means "the card shows no price" (out of stock, marketplace stub) — not "free":
            # keeping 0 would win every "cheapest" sort.
            f[k] = None if (v == 0 and k in ("price_uah", "price_min_uah", "price_max_uah")) else v
    if f["rating"] is not None:
        try:
            f["rating"] = float(str(f["rating"]).replace(",", "."))
        except ValueError:
            return None, "rating must be numeric"
    f["url"], f["model"] = f["url"].strip(), (f["model"] or "").strip()
    return f, None


def merge(old: dict, new: dict) -> dict:
    """Same URL seen again: lists union, price/rating/stock refresh, identity fields kept unless empty."""
    out = dict(old)
    for k, v in new.items():
        if k in ("id", "ts") or v in (None, "", []):
            continue
        if k in LIST_FIELDS:
            out[k] = _dedupe_ci(v, out.get(k, []))
        elif k in REFRESH_FIELDS or not out.get(k):
            out[k] = v
        elif k == "notes" and v not in out[k]:
            out[k] = f"{out[k]} | {v}"
    out["updated"] = now()
    return out


def add(topic: str, session: str, findings: list[dict] | dict) -> dict:
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    if isinstance(findings, dict):
        findings = [findings]
    if not isinstance(findings, list) or not all(isinstance(x, dict) for x in findings):
        return err("findings must be a list of objects")
    rows = read_jsonl(sp.findings)
    index = {normalize_url(r["url"]): i for i, r in enumerate(rows)}
    next_id = max([r.get("id") or 0 for r in rows] + [0]) + 1
    added, merged, errors = 0, 0, []
    for raw in findings:
        f, e = coerce(raw)
        if e:
            errors.append({"error": e, "finding": raw})
            continue
        key = normalize_url(f["url"])
        if key in index:
            rows[index[key]] = merge(rows[index[key]], f)
            merged += 1
        else:
            f["id"], f["ts"] = next_id, now()
            next_id += 1
            rows.append(f)
            index[key] = len(rows) - 1
            added += 1
    write_jsonl(sp.findings, rows)
    if meta["status"] == "draft" and (added or merged):
        meta["status"] = "searching"
    sessions.save(meta, sp, "findings_added", {"added": added, "merged": merged, "errors": len(errors)})
    return {"success": bool(added or merged) or not errors, "added": added, "merged": merged,
            "errors": errors, "total": len(rows)}


def list_(topic: str, session: str, group: str | None = None, model: str | None = None,
          fields: list[str] | None = None) -> dict:
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    rows = read_jsonl(sp.findings)
    if group:
        rows = [r for r in rows if r["group"] == group]
    if model:
        nm = normalize_model(model)
        rows = [r for r in rows if normalize_model(r.get("model")) == nm]
    if fields:
        rows = [{k: r.get(k) for k in fields} for r in rows]
    return {"success": True, "count": len(rows), "findings": rows}


def resume_context(topic: str, session: str, log_tail: int = 15) -> dict:
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return err(f"session {topic}/{session} not found",
                   sessions=sessions.list_sessions(topic).get("sessions"))
    rows = read_jsonl(sp.findings)
    by_group: dict[str, int] = {}
    models = set()
    for r in rows:
        by_group[r["group"]] = by_group.get(r["group"], 0) + 1
        if r.get("model"):
            models.add(r["model"])
    log = read_jsonl(sp.log)
    followups = sorted(p.name for p in sp.followups.glob("*.md")) if sp.followups.exists() else []
    return {"success": True, "session": meta, "path": str(sp.dir),
            "findings_total": len(rows), "findings_by_group": by_group, "models": sorted(models),
            "log_tail": log[-log_tail:], "followups": followups,
            "report_path": str(sp.report) if sp.report.exists() else None}
