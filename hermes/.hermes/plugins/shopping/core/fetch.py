"""Layer 2 — fetch service: run a site fetcher, keep only hits that match the model code, store as
findings, return a compact summary. This is what keeps raw HTML/JSON out of the model context."""
from __future__ import annotations

from . import fetchers, findings, sessions
from .fs import err, now
from .fetchers.hotline import parse_spec  # noqa: F401  (re-exported for tests)

MAX_REVIEW_CHARS = 350


def _tokens(model: str) -> list[str]:
    """Model-code tokens that must all appear in a title: 'MSI MAG 274QP QD-OLED X24' →
    ['274QP', 'QD-OLED', 'X24'] (drops brand-ish first token and 1-2 char noise)."""
    toks = [t for t in findings.normalize_model(model).split() if t] if " " in model else []
    raw = [t for t in model.replace("/", " ").split() if len(t) > 2]
    return raw[1:] if len(raw) > 2 else raw


def matches_model(title: str, model: str) -> bool:
    nt = findings.normalize_model(title)
    return all(findings.normalize_model(t) in nt for t in _tokens(model))


def _spec_ok(spec: dict, want: dict) -> bool:
    """want: {diagonal_in: [lo, hi], panel_any: [..], resolution: str, refresh_min: int}."""
    d = want.get("diagonal_in")
    if d and spec.get("diagonal_in") is not None and not (d[0] <= spec["diagonal_in"] <= d[1]):
        return False
    if want.get("panel_any") and not any(p.upper() in (spec.get("panel") or "").upper() for p in want["panel_any"]):
        return False
    if want.get("resolution") and spec.get("resolution") != want["resolution"]:
        return False
    if want.get("refresh_min") and (spec.get("refresh_hz") or 0) < want["refresh_min"]:
        return False
    return True


def catalog(topic: str, session: str, section: str, filter_ids: list[int], want: dict | None = None,
            max_pages: int = 6, store: bool = True) -> dict:
    """hotline category walk → candidate models. Stores aggregator findings; returns compact list."""
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    try:
        res = fetchers.get("hotline").catalog(section, filter_ids, max_pages=max_pages)
    except Exception as e:  # noqa: BLE001
        sessions.log_event(topic, session, "source_blocked", f"hotline catalog: {e}")
        return err(f"hotline catalog failed: {e}")
    cards = res["cards"]
    kept = [c for c in cards if _spec_ok(c["spec"], want or {})]
    rows = [{k: v for k, v in c.items() if k not in ("spec", "date")} | {"notes": c["notes"]} for c in kept]
    stored = findings.add(topic, session, rows) if store and rows else {"added": 0, "merged": 0}
    sessions.log_event(topic, session, "source_done",
                       f"hotline catalog {section}/{'-'.join(map(str, filter_ids))}: {len(cards)} cards, {len(kept)} match spec")
    return {"success": True, "source": "hotline", "scanned": len(cards), "matched": len(kept),
            "selected_filters": res["selected"], "stored": {k: stored[k] for k in ("added", "merged")},
            "candidates": [{"model": c["model"], "price_min_uah": c["price_min_uah"], "price_max_uah": c["price_max_uah"],
                            "offers": c["offers_count"], "reviews": c["rating_count"], "spec": c["spec"], "url": c["url"]}
                           for c in kept]}


def hotline_filters(section: str) -> dict:
    try:
        return {"success": True, "section": section, "filters": fetchers.get("hotline").filters(section)}
    except Exception as e:  # noqa: BLE001
        return err(f"hotline filters failed: {e}")


def _compact_offer(f: dict) -> dict:
    keys = ("source", "title", "url", "price_uah", "price_note", "price_min_uah", "price_max_uah", "rating", "rating_count",
            "offers_count", "availability", "seller", "installment", "installment_note", "delivery_scope")
    return {k: f[k] for k in keys if f.get(k) not in (None, "", [])}


def fetch(topic: str, session: str, site: str, model: str, geo: str = "ua_local", limit: int = 5,
          store: bool = True) -> dict:
    """Search `site` for `model`, keep title-matching hits, store as findings, return compact offers
    plus review texts (rozetka) / per-shop offers (hotline) for the model to read."""
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    try:
        mod = fetchers.get(site)
    except KeyError as e:
        return err(str(e))
    try:
        hits = mod.search(model) if site != "rozetka" else mod.search(model, limit=limit)
    except Exception as e:  # noqa: BLE001
        sessions.log_event(topic, session, "source_blocked", f"{site}: {model}: {e}")
        return err(f"{site} failed: {e}", site=site, model=model)
    matched = [h for h in hits if matches_model(h.get("title") or "", model)]
    if geo == "ua_local":
        matched = [h for h in matched if h.get("delivery_scope", "ua_local") == "ua_local"]
    matched = matched[:limit]
    extras = {}
    rows = []
    allowed = set(findings.defaults())
    for h in matched:
        h = dict(h)
        h["model"] = model
        reviews = h.pop("reviews", None)
        spec = h.pop("spec", None)
        if spec and not h.get("notes"):
            h["notes"] = "; ".join(f"{k}={v}" for k, v in spec.items() if v is not None)
        h = {k: v for k, v in h.items() if k in allowed}
        if reviews:
            extras.setdefault("reviews", []).extend(
                {"mark": r["mark"], "pros": r["pros"][:MAX_REVIEW_CHARS], "cons": r["cons"][:MAX_REVIEW_CHARS],
                 "text": r["text"][:MAX_REVIEW_CHARS]} for r in reviews)
        rows.append(h)
    if site == "hotline" and matched:
        try:
            off = mod.offers(matched[0]["url"])
            extras["shops"] = [{k: o[k] for k in ("shop", "price_uah", "installment_note", "guarantee", "shop_reviews", "from") if o.get(k) not in (None, "")}
                               for o in off["offers"][:12]]
            with_inst = sorted({o["shop"] for o in off["offers"] if o["installment"]})
            rows[0]["installment"] = bool(with_inst)
            rows[0]["installment_note"] = f"{len(with_inst)} из {len(off['offers'])} магазинов: " + ", ".join(with_inst[:6]) if with_inst else ""
        except Exception as e:  # noqa: BLE001
            extras["shops_error"] = str(e)
    stored = findings.add(topic, session, rows) if store and rows else {"added": 0, "merged": 0, "errors": []}
    if stored.get("errors"):
        sessions.log_event(topic, session, "note", f"{site}: {len(stored['errors'])} rows rejected: {stored['errors'][0]['error'][:120]}")
    sessions.log_event(topic, session, "source_done", f"{site}: {model}: {len(hits)} hits, {len(matched)} matched")
    return {"success": True, "site": site, "model": model, "hits": len(hits), "matched": len(matched),
            "stored": {k: stored.get(k) for k in ("added", "merged")} | ({"rejected": len(stored["errors"])} if stored.get("errors") else {}),
            "offers": [_compact_offer(r) for r in rows], **extras}
