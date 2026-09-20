"""Layer 2 — search plans: turn ONE set of criteria into a per-source search plan.

Sources differ: hotline/e-katalog expose category filters, marketplaces only take a text query,
and the words a site uses for the same parameter differ ("частота оновлення" vs "Частота"). The
plugin therefore does not translate anything by itself — it reports, per source, WHAT that source
can do (`capabilities`) and what its result set actually says (`observe`), and stores the plan the
MODEL writes from that:

    plans = [{"site": "hotline",   "query": "інвертор 24V", "criteria": [...], "strict": false},
             {"site": "rozetka",   "query": "інвертор 24В 3000Вт чистий синус", "criteria": [...]},
             {"site": "epicentr",  "query": "інвертор 24 220 3000", "criteria": [...], "note": "..."}]

`criteria` may differ per site precisely because each site words its specs differently; the
shared session-level criteria stay in `params.criteria` as the single source of truth for the
report. Running a plan is just fetch + evaluate, so nothing here knows a product category.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor

from . import fetch, sessions, sources, spec
from .fs import err

MAX_SAMPLE = 12


def capabilities(site_keys: list[str] | None = None) -> dict:
    """What each source offers a search: its own search URL shape, whether the plugin can read
    cards/reviews, and the free-text hints the source package declares (source.yaml `notes`,
    `filters` when a site documents structured ones). Model-facing, no product knowledge."""
    out = []
    for s in sources.all_sources():
        if site_keys and s.key not in site_keys:
            continue
        mod_caps: list[str] = []
        if s.scripted:
            try:
                mod = s.module()
            except Exception:  # noqa: BLE001
                mod = None
            for fn, cap in (("search", "search"), ("card", "card"), ("reviews", "reviews"),
                            ("offers", "offers")):
                if mod is not None and hasattr(mod, fn):
                    mod_caps.append(cap)
        out.append({"site": s.key, "title": s.title, "group": s.group, "fetch": s.fetch,
                    "scripted": s.scripted, "search_url": s.search, "can": mod_caps,
                    "notes": s.notes, "structured_filters": bool(s.filters)})
    return {"success": True, "sources": sorted(out, key=lambda x: (x["group"], x["site"]))}


def sample(site: str, query: str, limit: int = MAX_SAMPLE) -> dict:
    """Run one query against one source and report what the answers look like: a few titles plus
    `observe()` of their spec lines. This is how the model learns a site's own wording before
    writing that site's criteria."""
    try:
        mod = sources.get(site).module()
    except KeyError as e:
        return err(str(e))
    try:
        rows = mod.search(query)
    except Exception as e:  # noqa: BLE001
        return err(f"{site}: {e}", site=site)
    specs = [r.get("notes") or "" for r in rows]
    return {"success": True, "site": site, "query": query, "hits": len(rows),
            "titles": [(r.get("title") or "")[:90] for r in rows[:limit]],
            "observed": spec.observe(specs)}


def probe_plans(plans: list[dict], limit: int = MAX_SAMPLE) -> dict:
    """Dry-run every plan in parallel: how many hits each query returns and how many survive that
    plan's criteria — so the model can fix a bad query BEFORE spending a full fetch."""
    def one(plan: dict) -> dict:
        site, query = plan.get("site"), plan.get("query") or ""
        try:
            mod = sources.get(site).module()
            rows = mod.search(query)
        except Exception as e:  # noqa: BLE001
            return {"site": site, "query": query, "error": str(e)[:120]}
        kept, failed_reasons, no_spec = [], [], 0
        for r in rows:
            if not (r.get("notes") or "").strip():
                no_spec += 1
            ok, failed, unknown = spec.evaluate(r.get("notes") or "", plan.get("criteria"),
                                                plan.get("strict", False))
            (kept if ok else failed_reasons).append(r if ok else (failed or unknown))
        out = {"site": site, "query": query, "hits": len(rows), "kept": len(kept),
               "examples": [(r.get("title") or "")[:80] for r in kept[:4]],
               "dropped_example": "; ".join(failed_reasons[0])[:100] if failed_reasons else ""}
        if rows and no_spec / len(rows) > 0.5:
            # This source does not print specs in its result list, so criteria cannot filter it:
            # the plan's QUERY has to carry the parameters (and the card check happens later).
            out["spec_coverage"] = round(1 - no_spec / len(rows), 2)
            out["warning"] = "выдача без характеристик — критерии тут не фильтруют, параметры должны быть в query"
        return out

    with ThreadPoolExecutor(max_workers=min(8, max(len(plans), 1))) as ex:
        results = list(ex.map(one, plans))
    return {"success": True, "plans": results,
            "total_kept": sum(r.get("kept") or 0 for r in results)}


def run(topic: str, session: str, plans: list[dict], model: str | None = None,
        geo: str = "ua_local", limit: int = 5) -> dict:
    """Execute the plans: per plan, fetch its site with its query and keep rows that satisfy its
    criteria. Offers are stored as findings by `fetch`; the shared criteria decide what counts."""
    meta, _ = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    params = meta.get("params") or {}

    def one(plan: dict) -> dict:
        site = plan.get("site")
        query = plan.get("query") or model or params.get("query") or ""
        res = fetch.fetch(topic, session, site, model or query, geo=geo, limit=limit,
                          category=params.get("category") or None,
                          condition=params.get("condition") or "new",
                          criteria=plan.get("criteria") or params.get("criteria"),
                          strict=plan.get("strict", False), query=query)
        return {"site": site, "query": query, **{k: res.get(k) for k in ("success", "hits", "matched", "error")}}

    with ThreadPoolExecutor(max_workers=min(6, max(len(plans), 1))) as ex:
        results = list(ex.map(one, plans))
    sessions.log_event(topic, session, "source_done",
                       f"plans for {model or params.get('query')}: " +
                       ", ".join(f"{r['site']}:{r.get('matched', 'x')}" for r in results))
    return {"success": True, "model": model, "results": results,
            "matched_total": sum(r.get("matched") or 0 for r in results)}
