"""Layer 2 — probe service: a cheap parallel "is it worth searching here?" pass over scripted sites.

One free-text search per site, in threads; returns per-site hit counts + a few sample titles, nothing
is stored. Browser-only sites are listed with `probed: False` so the source menu can still offer them.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed

from . import query as q, sources

SAMPLE = 3
MAX_CATS = 6            # top categories by count kept per site (what the menu shows)
TIMEOUT_S = 40


def sites(exclude: list[str] | None = None) -> list[dict]:
    """All sources in catalogue order, with group/title/fetch method."""
    ex = set(exclude or [])
    return [{"site": s.key, "group": s.group, "title": s.title, "fetch": s.fetch, "scripted": s.scripted}
            for s in sources.all_sources() if s.key not in ex]


def _probe_one(site: str, query: str) -> dict:
    """Probe one site, widening the query until it answers: site search is AND-ish, so a full
    brief ("монітор 27 OLED 2K 100 Гц") returns zero almost everywhere while "монітор 27 OLED"
    returns the whole category. The query that worked is reported back."""
    meta: dict = {}
    err: str | None = None

    def run(variant: str):
        nonlocal err, meta
        meta = {}
        try:
            mod = sources.get(site).module()
            return mod.search(variant, meta, **(getattr(mod, "PROBE_KWARGS", {}) or {}))
        except Exception as e:  # noqa: BLE001 — a dead site must not kill the probe
            err = f"{type(e).__name__}: {e}"[:120]
            return None

    hits, used, tried = q.widen(query, run)
    if hits is None:
        return {"site": site, "probed": True, "error": err or "search failed", "hits": 0, "sample": []}
    seen, cats = set(), []
    for c in meta.get("categories") or []:
        if c.get("name") and c["name"] not in seen:
            seen.add(c["name"])
            cats.append(c)
    cats.sort(key=lambda c: -(c.get("count") or 0))
    return {"site": site, "probed": True, "hits": len(hits), "total_est": meta.get("total_est"),
            "query_used": used, "query_tried": tried if len(tried) > 1 else None,
            "categories": cats[:MAX_CATS],
            "sample": [{"title": (h.get("title") or "")[:90], "price_uah": h.get("price_uah")} for h in hits[:SAMPLE]]}


def probe(query: str, exclude: list[str] | None = None, only: list[str] | None = None) -> dict:
    """Parallel search on every scripted site (minus `exclude`, or just `only`)."""
    if not (query or "").strip():
        return {"success": False, "error": "query must not be empty"}
    todo = sites(exclude)
    if only:
        todo = [s for s in todo if s["site"] in set(only)]
    results: dict[str, dict] = {}
    scripted = [s["site"] for s in todo if s["scripted"]]
    if not scripted:
        return {"success": False, "error": "no scripted site left to probe", "sites": []}
    with ThreadPoolExecutor(max_workers=min(8, max(1, len(scripted)))) as pool:
        futs = {pool.submit(_probe_one, s, query): s for s in scripted}
        try:
            for f in as_completed(futs, timeout=TIMEOUT_S):
                r = f.result()
                results[r["site"]] = r
        except TimeoutError:            # slow/throttled sources: report what came back in time
            for f, s in futs.items():
                if f.done() and s not in results:
                    results[s] = f.result()
    rows = []
    for s in sites():
        r = results.get(s["site"])
        if r is not None:
            status = "error" if r.get("error") else ("hits" if r["hits"] else "zero")
        elif not s["scripted"]:
            status = "no_script"         # browser-only site: nothing to probe with
        elif s["site"] in set(exclude or []) or (only and s["site"] not in set(only)):
            status = "excluded"          # user chose not to probe it
        else:
            status = "not_probed"
        rows.append(s | (r or {"probed": False, "hits": None, "sample": []}) | {"status": status})
    return {"success": True, "query": query, "sites": rows,
            "with_hits": [r["site"] for r in rows if r["status"] == "hits"],
            "unprobed": [r["site"] for r in rows if r["status"] in ("excluded", "no_script", "not_probed")]}
