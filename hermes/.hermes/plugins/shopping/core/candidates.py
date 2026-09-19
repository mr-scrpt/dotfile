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

from . import findings, sessions, sources
from .findings import model_key
from .fs import err

MAX_CANDIDATES = 40


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
    return {"model": r.get("model") or r.get("title"), "price_min_uah": r.get("price_min_uah"),
            "price_max_uah": r.get("price_max_uah"), "offers": r.get("offers_count"), "reviews": r.get("rating_count"),
            "spec": (r.get("notes") or "")[:160], "url": r["url"], "category": r.get("category") or ""}


def discover(topic: str, session: str, query: str, category: str | None = None, pages: int = 2,
             store: bool = True) -> dict:
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    category = category or (meta.get("params") or {}).get("category") or None
    errors: list[str] = []
    with ThreadPoolExecutor(max_workers=2) as ex:
        fh = ex.submit(_hotline, query, pages, category)
        fe = ex.submit(_ekatalog, query)
    rows: list[dict] = []
    cats: list[dict] = []
    for name, fut in (("hotline", fh), ("ekatalog", fe)):
        try:
            got, m = fut.result()
            rows += got
            cats += m.get("categories") or []
        except Exception as e:  # noqa: BLE001
            errors.append(f"{name}: {e}")
            sessions.log_event(topic, session, "source_blocked", f"{name} candidates: {e}")
    scanned = len(rows)
    rows = [r for r in rows if _category_ok(r, category)]
    ranked = rank(rows)[:MAX_CANDIDATES]
    for r in ranked:
        r.pop("spec", None)
        r.pop("date", None)
    allowed = set(findings.defaults())
    stored = findings.add(topic, session, [{k: v for k, v in r.items() if k in allowed} for r in ranked]) \
        if store and ranked else {"added": 0, "merged": 0}
    sessions.log_event(topic, session, "source_done",
                       f"candidates {query!r}: {scanned} cards, {len(ranked)} models" + (f" ({', '.join(errors)})" if errors else ""))
    if not ranked and not errors:
        return err(f"no candidates for {query!r} — try a shorter query (brand/type only) or another category", scanned=scanned)
    return {"success": True, "query": query, "category": category, "scanned": scanned, "models": len(ranked),
            "categories": cats[:8], "errors": errors, "stored": {k: stored[k] for k in ("added", "merged")},
            "candidates": [compact(r) for r in ranked]}
