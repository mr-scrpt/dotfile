"""Layer 2 — probe service: a cheap parallel "is it worth searching here?" pass over scripted sites.

One free-text search per site, in threads; returns per-site hit counts + a few sample titles, nothing
is stored. Browser-only sites are listed with `probed: False` so the source menu can still offer them.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed

from . import catalog, fetchers

SAMPLE = 3
TIMEOUT_S = 40
SEARCHABLE_GROUPS = ("aggregators", "marketplaces", "shops")


def sites(exclude: list[str] | None = None) -> list[dict]:
    """All searchable sites from sources.yaml in catalogue order, with group/title/fetch method."""
    src = catalog.load()
    ex = set(exclude or [])
    out = []
    for group in SEARCHABLE_GROUPS:
        for key, cfg in (src.get(group) or {}).items():
            if key in ex:
                continue
            out.append({"site": key, "group": group, "title": cfg.get("title", key),
                        "fetch": cfg.get("fetch", "browser"), "scripted": key in fetchers.REGISTRY})
    return out


def _probe_one(site: str, query: str) -> dict:
    meta: dict = {}
    try:
        hits = fetchers.get(site).search(query, meta, limit=SAMPLE, comments_pages=0) if site == "rozetka" else fetchers.get(site).search(query, meta)
    except Exception as e:  # noqa: BLE001 — a dead site must not kill the probe
        return {"site": site, "probed": True, "error": f"{type(e).__name__}: {e}"[:120], "hits": 0, "sample": []}
    return {"site": site, "probed": True, "hits": len(hits), "total_est": meta.get("total_est"),
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
    with ThreadPoolExecutor(max_workers=min(8, max(1, len(scripted)))) as pool:
        futs = {pool.submit(_probe_one, s, query): s for s in scripted}
        for f in as_completed(futs, timeout=TIMEOUT_S):
            r = f.result()
            results[r["site"]] = r
    rows = []
    for s in todo:
        r = results.get(s["site"], {"probed": False, "hits": None, "sample": []})
        rows.append(s | r)
    return {"success": True, "query": query, "sites": rows,
            "with_hits": [r["site"] for r in rows if r.get("hits")],
            "unprobed": [r["site"] for r in rows if not r.get("probed")]}
