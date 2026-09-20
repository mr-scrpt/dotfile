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

from . import findings, query as q, sessions, sources, spec
from .findings import model_key
from .fs import err

MAX_CANDIDATES = 40
NARROW_ABOVE = 20       # more survivors than this → go back to the user and narrow the criteria
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


def _interleave(groups: list[list[dict]]) -> list[dict]:
    """Round-robin over per-query result lists, deduped — so every alternative the user allows
    is represented in the shortlist, not just the one with the most offers on the market."""
    out: list[dict] = []
    seen: set[str] = set()
    for i in range(max((len(g) for g in groups), default=0)):
        for g in groups:
            if i >= len(g):
                continue
            k = model_key(g[i])
            if k and k not in seen:
                seen.add(k)
                out.append(g[i])
    return out


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


def narrow_suggestions(lines: list[str], top: int = 6) -> list[dict]:
    """Which parameters would actually split this result set — the material for asking the user
    to narrow. Purely statistical: keys most cards state, with several distinct values."""
    out = []
    for o in spec.observe(lines, top=4, min_share=0.4):
        if len(o.get("values") or []) < 2:
            continue
        out.append({"key": o["key"], "coverage": o["coverage"],
                    "values": o["values"], "units": o.get("units")})
    return out[:top]


def compact(r: dict) -> dict:
    out = {"model": r.get("model") or r.get("title"), "price_min_uah": r.get("price_min_uah"),
           "price_max_uah": r.get("price_max_uah"), "offers": r.get("offers_count"), "reviews": r.get("rating_count"),
           "spec": (r.get("notes") or "")[:160], "url": r["url"], "category": r.get("category") or ""}
    if r.get("unverified"):
        out["unverified"] = r["unverified"]          # constraints this card's spec does not state
    return out


def shorter(query: str) -> str | None:
    """Next, wider variant of a query (see core.query.variants) or None when it cannot widen."""
    vs = q.variants(query, max_attempts=2)
    return vs[1] if len(vs) > 1 else None


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


def discover(topic: str, session: str, query: str | list[str], category: str | None = None, pages: int = 2,
             criteria: list[dict] | None = None, strict: bool = False, store: bool = True,
             widen: bool = True) -> dict:
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
    # Several queries = one search: alternatives the user allows ("OLED або Mini LED") cannot be
    # expressed in ONE site query, because site search is AND-ish. Results are merged and ranked
    # together, so the user still gets a single comparable list.
    queries = [query] if isinstance(query, str) else list(query)
    if len(queries) > 1:
        merged: list[dict] = []
        all_tried: list[str] = []
        observed_src: list[str] = []
        dropped_all: list[dict] = []
        per_query: list[list[dict]] = []
        for sub in queries:
            part = discover(topic, session, sub, category, pages, criteria, strict, store, widen=False)
            all_tried += part.get("query_tried") or [sub]
            dropped_all += part.get("dropped_by_spec") or []
            if part.get("success"):
                per_query.append(part.get("_rows") or [])
                merged += part.get("_rows") or []
                observed_src += part.get("_specs") or []
        # Interleave the alternatives instead of concatenating them: each query is a DIFFERENT
        # thing the user allows ("OLED або Mini LED"), and a niche alternative has far fewer
        # offers than a mainstream one, so a plain merge + cut would silently drop it entirely.
        ranked_all = _interleave([rank(rows) for rows in per_query])[:MAX_CANDIDATES]
        specs_all = [r.get("notes") or "" for r in ranked_all]
        return {"success": bool(ranked_all), "query": " | ".join(queries), "query_tried": all_tried,
                "category": category, "scanned": len(merged), "models": len(ranked_all),
                "categories": [], "errors": [],
                "needs_narrowing": len(ranked_all) > NARROW_ABOVE,
                "narrow_suggestions": narrow_suggestions(specs_all) if len(ranked_all) > NARROW_ABOVE else [],
                "observed": spec.observe(observed_src), "criteria_shown": spec.describe(criteria),
                "dropped_by_spec": dropped_all[:6], "dropped_count": len(dropped_all),
                "stored": {"added": 0, "merged": 0},
                "candidates": [compact(r) for r in ranked_all]}
    tried: list[str] = []
    dropped_by_spec: list[dict] = []
    q = queries[0]
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
        nxt = shorter(q) if widen else None
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
    specs_kept = [r.get("notes") or "" for r in ranked]
    return {"success": True, "query": tried[-1], "query_tried": tried, "category": category, "scanned": scanned,
            "models": len(ranked), "categories": cats[:8], "errors": errors,
            "needs_narrowing": len(ranked) > NARROW_ABOVE,
            "narrow_suggestions": narrow_suggestions(specs_kept) if len(ranked) > NARROW_ABOVE else [],
            "observed": spec.observe([r.get("notes") or "" for r in in_cat]),
            "criteria_shown": spec.describe(criteria),
            "dropped_by_spec": dropped_by_spec[:6], "dropped_count": len(dropped_by_spec),
            "stored": {k: stored[k] for k in ("added", "merged")},
            "candidates": [compact(r) for r in ranked],
            "_rows": ranked, "_specs": [r.get("notes") or "" for r in in_cat]}
