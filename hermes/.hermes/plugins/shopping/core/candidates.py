"""Layer 2 — candidates: universal shortlist discovery for ANY product category.

Searches the aggregators (hotline: up to `pages` result pages, ekatalog: first page) with the
user's query, keeps only cards whose aggregator category matches `category` (when given — the
name the user picked from the probe), dedupes by model, ranks by market presence
(offers × reviews) and stores the rows as aggregator findings. The model reads
`notes` (the aggregator's short spec line) to check the user's `must` list — there are no
per-category filter ids or spec parsers anywhere.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor

from . import findings, sessions, sources, spec
from .findings import model_key
from .fs import err

MAX_CANDIDATES = 40
MIN_MODELS = 5          # below this the query counts as too narrow → retry with fewer words
MAX_ATTEMPTS = 3


def _hotline(query: str, pages: int, category: str | None) -> tuple[list[dict], dict]:
    mod = sources.get("hotline").module()
    meta: dict = {}
    rows = mod.search(query, meta)
    for p in range(2, pages + 1):
        if len(rows) < 48 * (p - 1):
            break
        rows += mod.search_page(query, p)
    return rows, meta


def _ekatalog(query: str) -> tuple[list[dict], dict]:
    meta: dict = {}
    return sources.get("ekatalog").module().search(query, meta), meta


def _category_ok(row: dict, category: str | None) -> bool:
    if not category:
        return True
    c = (row.get("category") or "").lower()
    return not c or category.lower() in c or c in category.lower()


def rank(rows: list[dict]) -> list[dict]:
    """Dedupe by model (aggregator rows for the same model merge: keep both links in `also`),
    sort by offers count desc, then reviews desc, then price asc."""
    by: dict[str, dict] = {}
    for r in rows:
        k = model_key(r)
        if not k:
            continue
        cur = by.get(k)
        if cur is None:
            by[k] = dict(r, also=[])
        else:
            cur["also"].append({"source": r["source"], "url": r["url"], "price_min_uah": r.get("price_min_uah")})
            for f in ("offers_count", "rating_count"):
                cur[f] = max(cur.get(f) or 0, r.get(f) or 0) or None
            if not cur.get("notes") and r.get("notes"):
                cur["notes"] = r["notes"]
    return sorted(by.values(), key=lambda r: (-(r.get("offers_count") or 0), -(r.get("rating_count") or 0),
                                              r.get("price_min_uah") or 10**9))


def compact(r: dict) -> dict:
    out = {"model": r.get("model") or r.get("title"), "price_min_uah": r.get("price_min_uah"),
           "price_max_uah": r.get("price_max_uah"), "offers": r.get("offers_count"), "reviews": r.get("rating_count"),
           "spec": (r.get("notes") or "")[:160], "url": r["url"], "category": r.get("category") or ""}
    if r.get("unverified"):
        out["unverified"] = r["unverified"]          # constraints this card's spec does not state
    return out


def shorter(query: str) -> str | None:
    """Drop the least selective trailing word (aggregator search is AND-ish: every extra word
    narrows the result set). 'інвертор 24V чистий синус' → 'інвертор 24V чистий' → 'інвертор 24V'."""
    words = query.split()
    return " ".join(words[:-1]) if len(words) > 2 else None


def _search_all(query: str) -> tuple[list[dict], list[dict], list[str]]:
    errors: list[str] = []
    rows: list[dict] = []
    cats: list[dict] = []
    with ThreadPoolExecutor(max_workers=2) as ex:
        futs = {"hotline": ex.submit(_hotline, query, 2, None), "ekatalog": ex.submit(_ekatalog, query)}
    for name, fut in futs.items():
        try:
            got, m = fut.result()
            rows += got
            cats += m.get("categories") or []
        except Exception as e:  # noqa: BLE001
            errors.append(f"{name}: {e}")
    return rows, cats, errors


def discover(topic: str, session: str, query: str, category: str | None = None, pages: int = 2,
             criteria: list[dict] | None = None, strict: bool = False, store: bool = True) -> dict:
    """Search the aggregators and filter by `criteria` — the parameter list the MODEL authored
    (see core.spec). Rows whose spec is silent about a criterion are kept and flagged
    `unverified` unless `strict=True`. The response always carries `observed`: the keys, values
    and per-unit ranges this result set really contains — the material for authoring or
    refining criteria (case 3: call once without criteria, read `observed`, ask the user)."""
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    category = category or (meta.get("params") or {}).get("category") or None
    errors: list[str] = []
    tried: list[str] = []
    dropped_by_spec: list[dict] = []
    q = query
    rows: list[dict] = []
    cats: list[dict] = []
    ranked: list[dict] = []
    scanned = 0
    for _ in range(MAX_ATTEMPTS):
        tried.append(q)
        rows, cats, errs = _search_all(q)
        for e in errs:
            sessions.log_event(topic, session, "source_blocked", f"candidates {q!r}: {e}")
        errors = errs
        scanned = len(rows)
        in_cat = [r for r in rows if _category_ok(r, category)]
        kept: list[dict] = []
        for r in in_cat:
            ok, failed, unknown = spec.evaluate(r.get("notes") or "", criteria, strict)
            if not ok:
                dropped_by_spec.append({"model": r.get("model") or r.get("title"),
                                        "why": "; ".join(failed or unknown)[:120]})
                continue
            kept.append(dict(r, unverified=unknown) if unknown else r)
        ranked = rank(kept)[:MAX_CANDIDATES]
        nxt = shorter(q)
        if len(ranked) >= MIN_MODELS or not nxt:
            break
        dropped_by_spec = []
        q = nxt
    for r in ranked:
        r.pop("spec", None)
        r.pop("date", None)
    allowed = set(findings.defaults())
    stored = findings.add(topic, session, [{k: v for k, v in r.items() if k in allowed} for r in ranked]) \
        if store and ranked else {"added": 0, "merged": 0}
    sessions.log_event(topic, session, "source_done",
                       f"candidates {tried[-1]!r} (tried {len(tried)}): {scanned} cards, {len(ranked)} models"
                       + (f", {len(dropped_by_spec)} dropped by criteria" if dropped_by_spec else "")
                       + (f" ({', '.join(errors)})" if errors else ""))
    if not ranked and not errors:
        hint = ("all cards failed the criteria — loosen one or re-read `observed`"
                if dropped_by_spec else "try a shorter query (brand/type only) or another category")
        return err(f"no candidates for {query!r} — {hint}", scanned=scanned,
                   observed=spec.observe([r.get("notes") or "" for r in in_cat]),
                   dropped_by_spec=dropped_by_spec[:6])
    return {"success": True, "query": tried[-1], "query_tried": tried, "category": category, "scanned": scanned,
            "models": len(ranked), "categories": cats[:8], "errors": errors,
            "observed": spec.observe([r.get("notes") or "" for r in in_cat]),
            "criteria_shown": spec.describe(criteria),
            "dropped_by_spec": dropped_by_spec[:6], "dropped_count": len(dropped_by_spec),
            "stored": {k: stored[k] for k in ("added", "merged")},
            "candidates": [compact(r) for r in ranked]}
