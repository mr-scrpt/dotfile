"""Layer 2 — compare: gather EVERY surviving model's facts into one table the model can judge.

The shortlist is never decided before reviews exist: a model with 1200 dimming zones may still
lose to one with 300 if buyers complain about it. So this service

  1. takes every candidate that passed the criteria,
  2. fetches offers (prices, availability) and buyer reviews for ALL of them in parallel,
  3. returns one compact row per model: spec line, best price, offer count, rating + review count,
     the strongest complaint signals, and which criteria are still `unverified`,

and the MODEL then picks the three leaders from the full picture (see SKILL step "вердикт").
The plugin deliberately does NOT rank the leaders itself — the trade-off between specs, reviews
and price is a judgement call, not a formula.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor

from . import findings, plans, reviews as reviews_mod, sessions, spec
from .fs import err

MAX_MODELS = 24            # above this the caller must narrow first (see candidates.NARROW_ABOVE)
SIGNALS_PER_MODEL = 4
SIGNAL_CHARS = 180


def _best_offer(rows: list[dict]) -> dict:
    priced = [r for r in rows if r.get("price_uah")]
    if not priced:
        ranged = [r for r in rows if r.get("price_min_uah")]
        return min(ranged, key=lambda r: r["price_min_uah"]) if ranged else {}
    in_stock = [r for r in priced if "немає" not in (r.get("availability") or "").lower()]
    return min(in_stock or priced, key=lambda r: r["price_uah"])


def _row_for(topic: str, session: str, model: str, criteria: list[dict] | None) -> dict:
    rows = findings.list_(topic, session, model=model)["findings"]
    offers = [r for r in rows if r["group"] == "marketplace"]
    aggs = [r for r in rows if r["group"] == "aggregator"]
    revs = [r for r in rows if r["group"] == "review"]
    best = _best_offer(offers) or _best_offer(aggs)
    spec_line = next((r.get("notes") for r in aggs + offers if r.get("notes")), "")
    rated = [r for r in revs + offers + aggs if r.get("rating") and r.get("rating_count")]
    top_rated = max(rated, key=lambda r: r["rating_count"]) if rated else {}
    complaints: list[str] = []
    praise: list[str] = []
    for r in revs:
        complaints += [n for n in (r.get("nuances") or []) if n]
        praise += [p for p in (r.get("pros") or []) if p]
    _, failed, unknown = spec.evaluate(dict(best, notes=spec_line), criteria)
    return {
        "model": model,
        "spec": (spec_line or "")[:200],
        "price_uah": best.get("price_uah") or best.get("price_min_uah"),
        "price_note": best.get("price_note") or "",
        "shop": best.get("source") or "",
        "offers": max([r.get("offers_count") or 0 for r in aggs] + [len(offers)]),
        "rating": top_rated.get("rating"),
        "rating_count": sum(r.get("rating_count") or 0 for r in revs) or top_rated.get("rating_count"),
        "review_sites": sorted({r["source"].replace("-reviews", "") for r in revs}),
        "complaints": [c[:SIGNAL_CHARS] for c in complaints[:SIGNALS_PER_MODEL]],
        "praise": [p[:SIGNAL_CHARS] for p in praise[:2]],
        "unverified": unknown[:3],
        "failed": failed[:2],
    }


def build(topic: str, session: str, models: list[str] | None = None, sites: list[str] | None = None,
          geo: str = "ua_local", plans_by_model: dict | None = None) -> dict:
    """Fetch offers + reviews for EVERY model, then return the comparison table.

    `plans_by_model` (optional) maps model → per-source plans from shop_source_plan; without it
    every chosen site is searched by the model code.
    """
    meta, _ = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    params = meta.get("params") or {}
    criteria = params.get("criteria") or None
    sites = sites or params.get("sites") or []
    if not sites:
        return err("params.sites is empty — ask the user which sources to search first")
    models = models or params.get("shortlist") or []
    if not models:
        return err("no models given and params.shortlist is empty")
    if len(models) > MAX_MODELS:
        return err(f"{len(models)} моделей — слишком много для полного сбора; сузьте критерии "
                   f"(shop_candidates вернёт narrow_suggestions) и повторите", models=len(models))

    def one(model: str) -> dict:
        model_plans = (plans_by_model or {}).get(model) or [{"site": s, "query": model} for s in sites]
        offers = plans.run(topic, session, model_plans, model=model, geo=geo)
        revs = reviews_mod.collect(topic, session, model) if params.get("reviews", "cards") != "none" else {}
        return {"model": model, "offers_matched": offers.get("matched_total"),
                "review_sites": len(revs.get("sources") or []),
                "signals": len(revs.get("signals") or [])}

    with ThreadPoolExecutor(max_workers=4) as ex:      # per-host pacing lives in core.throttle
        progress = list(ex.map(one, models))
    table = [_row_for(topic, session, m, criteria) for m in models]
    table.sort(key=lambda r: (-(r.get("rating_count") or 0), r.get("price_uah") or 10**9))
    sessions.log_event(topic, session, "source_done",
                       f"compare: {len(models)} моделей, "
                       f"{sum(p['offers_matched'] or 0 for p in progress)} офферов, "
                       f"{sum(p['signals'] for p in progress)} сигналов из отзывов")
    return {"success": True, "models": len(table), "table": table,
            "no_reviews": [r["model"] for r in table if not r["rating_count"]],
            "note": "выбери 3 лидера из ЭТОЙ таблицы: характеристики + отзывы + цена; "
                    "модель с лучшими характеристиками может уступить из-за жалоб"}
