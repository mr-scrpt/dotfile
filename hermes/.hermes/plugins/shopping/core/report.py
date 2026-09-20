"""Layer 3 — presentation: render report.md and follow-up files from session state. Pure: reads state, writes md."""
from __future__ import annotations

from typing import Any

from .findings import model_key
from .fs import append_jsonl, now, read_jsonl, slugify
from .model import GEO_LABEL
from . import sessions

def _n(v: int) -> str:
    return f"{v:,}".replace(",", " ")


def cell(s: Any) -> str:
    return str(s if s is not None else "").replace("|", "\\|").replace("\n", " ").strip()


def link(f: dict, label: str | None = None) -> str:
    return f"[{cell(label or f.get('source') or 'ссылка')}]({f['url']})"


def fmt_price(f: dict) -> str:
    if f.get("price_uah") is not None:
        s = f"{_n(f['price_uah'])} ₴"
    elif f.get("price_min_uah") is not None:
        hi = _n(f["price_max_uah"]) if f.get("price_max_uah") is not None else "?"
        s = f"{_n(f['price_min_uah'])} – {hi} ₴"
    else:
        s = "—"
    return f"{s} ({f['price_note']})" if f.get("price_note") else s


def fmt_rating(f: dict) -> str:
    """'4.4 (79)' | '4.4' | '— (1 отз.)' | '—'. A zero count means "no ratings" → '—'."""
    r, n = f.get("rating"), f.get("rating_count")
    if not n and not r:
        return "—"
    if r is None:
        return f"— ({n} отз.)"
    return f"{r:g} ({n})" if n is not None else f"{r:g}"


def fmt_installment(f: dict) -> str:
    v = f.get("installment")
    base = "да" if v is True else "нет" if v is False else "?"
    return f"{base}: {f['installment_note']}" if f.get("installment_note") else base


def _dedupe(items: list[str], limit: int = 6) -> list[str]:
    seen, out = set(), []
    for it in items:
        if it.lower() not in seen:
            seen.add(it.lower())
            out.append(it)
    return out[:limit]


def _params_block(p: dict) -> list[str]:
    lines = [f"- Запрос: {p['query']}"]
    if p.get("purpose"):
        lines.append(f"- Назначение: {p['purpose']}")
    for key, label in (("must", "Обязательно"), ("nice", "Желательно"), ("extra", "Доп. условия")):
        if p.get(key):
            lines.append(f"- {label}: " + "; ".join(p[key]))
    if p.get("budget_uah"):
        lines.append(f"- Бюджет: до {_n(p['budget_uah'])} ₴")
    lines.append(f"- Гео: {GEO_LABEL[p['geo']]}")
    if p.get("notes"):
        lines.append(f"- Заметки: {p['notes']}")
    return lines


def _collapse_offers(items: list[dict]) -> list[dict]:
    """One row per (model, source, seller): the cheapest in-stock offer wins; duplicates are counted."""
    from .sources.rozetka.fetcher import seller_from_url
    best: dict[tuple, dict] = {}
    for f in items:
        if f.get("source") == "rozetka" and not f.get("seller"):
            f = dict(f, seller=seller_from_url(f.get("url") or ""))
        key = (model_key(f), f.get("source"), (f.get("seller") or "").lower())
        cur = best.get(key)
        rank = (("немає" in (f.get("availability") or "")), f.get("price_uah") is None, f.get("price_uah") or 0)
        if cur is None or rank < cur["_rank"]:
            dup = (cur["_dups"] + 1) if cur else 0
            best[key] = dict(f, _rank=rank, _dups=dup)
        else:
            cur["_dups"] += 1
    return list(best.values())


def _pick_lines(pk: dict, offers: list[dict], aggs: list[dict], reviews: list[dict]) -> list[str]:
    """One pick: header with the best price + links, then offers table, aggregator links, pros/cons."""
    out = []
    offers = sorted(_collapse_offers(offers), key=lambda f: (f.get("price_uah") is None, f.get("price_uah") or 0))
    best = next((f for f in offers if f.get("price_uah") is not None and "немає" not in (f.get("availability") or "")), None)
    head = f"### {cell(pk.get('model'))}"
    if best:
        head += f" — от {_n(best['price_uah'])} ₴ ({link(best)})"
    out += [head, ""]
    if pk.get("why"):
        out += [pk["why"], ""]
    if offers:
        out += ["| Магазин | Цена | Рейтинг | Рассрочка | Продавец / наличие |", "|---|---|---|---|---|"]
        for f in offers:
            seller = " / ".join(x for x in (cell(f.get("seller")), cell(f.get("availability"))) if x) or "—"
            if f.get("_dups"):
                seller += f" (+{f['_dups']})"
            out.append(f"| {link(f)} | {cell(fmt_price(f))} | {cell(fmt_rating(f))} | {cell(fmt_installment(f))} | {seller} |")
        out.append("")
    if aggs:
        out.append("Агрегаторы: " + " · ".join(f"{link(a)} {cell(fmt_price(a))}" + (f", {a['offers_count']} предл." if a.get("offers_count") else "")
                                                for a in sorted(aggs, key=lambda a: a.get("source", ""))))
        out.append("")
    pros = _dedupe([x for r in reviews for x in (r.get("pros") or [])] + list(pk.get("pros") or []), 8)
    cons = _dedupe([x for r in reviews for x in (r.get("nuances") or []) + (r.get("cons") or [])] + list(pk.get("cons") or []), 8)
    if pros:
        out += ["Плюсы:"] + [f"- ＋ {x}" for x in pros]
    if cons:
        out += ["Минусы / нюансы:"] + [f"- ⚠ {x}" for x in cons]
    srcs = [link(r, r.get("source") or "источник") for r in reviews]
    if srcs:
        out.append("Отзывы: " + " · ".join(srcs))
    return out + [""]


def _spec_leaders_block(s: dict) -> list[str]:
    """Models that win on paper but did not make the picks — with the reason (usually reviews).
    Stored by shop_set_summary(spec_leaders=[{model, why, verdict}])."""
    rows = s.get("spec_leaders") or []
    if not rows:
        return []
    out = ["## 3b. Лидеры по характеристикам", "",
           "Формально лучшие по параметрам — но в тройку не вошли:", "",
           "| Модель | Чем лучше на бумаге | Почему не в тройке |", "|---|---|---|"]
    for r in rows:
        out.append(f"| {cell(r.get('model'))} | {cell(r.get('why'))} | {cell(r.get('verdict'))} |")
    return out + [""]


def _others_block(models: list[str], by_model: dict[str, list[dict]], aggs_by: dict[str, list[dict]]) -> list[str]:
    if not models:
        return []
    out = ["## 4. Все прошедшие критерии", "", "| Модель | Цена от | Где | Рейтинг |", "|---|---|---|---|"]
    for mk in models:
        rows = _collapse_offers(by_model.get(mk, [])) + aggs_by.get(mk, [])
        if not rows:
            continue
        best = min(rows, key=lambda f: (f.get("price_uah") is None and f.get("price_min_uah") is None,
                                         f.get("price_uah") or f.get("price_min_uah") or 0))
        rated = max(rows, key=lambda f: f.get("rating_count") or 0)
        out.append(f"| {cell(best.get('model') or best.get('title'))} | {cell(fmt_price(best))} | {link(best)} | {cell(fmt_rating(rated))} |")
    return out + [""]


def _followups_block(sp) -> list[str]:
    files = sorted(sp.followups.glob("*.md")) if sp.followups.exists() else []
    if not files:
        return []
    out = ["## 5. Уточнения", ""]
    for fp in files:
        first = fp.read_text(encoding="utf-8").splitlines()[0].lstrip("# ").strip() if fp.stat().st_size else fp.stem
        out.append(f"- [{cell(first)}](followups/{fp.name})")
    return out + [""]


def _reference_block(p: dict) -> list[str]:
    ref = p.get("reference") or {}
    if not ref:
        return []
    out = [f"- Образец: [{cell(ref.get('title'))}]({ref.get('url')})"]
    spec = ref.get("spec") or {}
    if spec:
        out.append("  - " + "; ".join(f"{k}: {v}" for k, v in list(spec.items())[:8]))
    for it in p.get("items") or []:
        out.append(f"- Нужно: {it.get('name')}" + (" — " + "; ".join(it.get("must") or []) if it.get("must") else ""))
    return out


def render(topic: str, session: str, full: bool = False) -> dict:
    """Write report.md: parameters → 1. best picks (links) → 2. per-pick summary (offers, aggregators,
    pros/cons) → 3. comparison (verdict + caveats) → 4. other candidates → 5. follow-ups.
    Returns a compact summary; the markdown only with `full=True` (the agent shows the file via read_file)."""
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    rows = read_jsonl(sp.findings)
    by = {g: [f for f in rows if f["group"] == g] for g in ("marketplace", "aggregator", "review")}
    by["marketplace"] += [f for f in rows if f["group"] == "shop"]   # legacy sessions
    offers_by: dict[str, list[dict]] = {}
    aggs_by: dict[str, list[dict]] = {}
    reviews_by: dict[str, list[dict]] = {}
    for g, dst in (("marketplace", offers_by), ("aggregator", aggs_by), ("review", reviews_by)):
        for f in by[g]:
            dst.setdefault(model_key(f), []).append(f)
    p = meta["params"]
    s = meta.get("summary") or {}
    picks = s.get("picks") or []
    pick_keys = [model_key({"model": pk.get("model", "")}) for pk in picks]
    all_keys = sorted(set(offers_by) | set(aggs_by), key=lambda k: (k not in pick_keys, k))
    others = [k for k in all_keys if k not in pick_keys]
    lines = [f"# {meta['topic']}: {p['query']}", "",
             f"Сессия `{meta['id']}` · статус: {meta['status']} · обновлено: {meta['updated'][:16].replace('T', ' ')}", "",
             "## Параметры поиска", "", *_params_block(p), *_reference_block(p), "",
             "## 1. Лучшие позиции", ""]
    if picks:
        for i, pk in enumerate(picks, 1):
            mk = pick_keys[i - 1]
            offers = sorted(_collapse_offers(offers_by.get(mk, [])), key=lambda f: (f.get("price_uah") is None, f.get("price_uah") or 0))
            best = next((f for f in offers if f.get("price_uah") is not None), None)
            price = f"от {_n(best['price_uah'])} ₴ · {link(best)}" if best else "цена: см. ниже"
            lines.append(f"{i}. **{cell(pk.get('model'))}** — {price}" + (f" — {cell(pk['why'])}" if pk.get("why") else ""))
        lines.append("")
    else:
        lines += ["_итог ещё не подведён_", ""]
    lines += ["## 2. По каждой позиции", ""]
    for pk, mk in zip(picks, pick_keys):
        lines += _pick_lines(pk, offers_by.get(mk, []), aggs_by.get(mk, []), reviews_by.get(mk, []))
    if not picks:
        lines += ["_—_", ""]
    lines += ["## 3. Сравнение и вывод", ""]
    lines += [s["verdict"], ""] if s.get("verdict") else ["_—_", ""]
    if s.get("caveats"):
        lines += ["Оговорки:"] + [f"- {c}" for c in s["caveats"]] + [""]
    lines += _spec_leaders_block(s)
    lines += _others_block(others, offers_by, aggs_by)
    lines += _followups_block(sp)
    md = "\n".join(lines)
    sp.report.write_text(md, encoding="utf-8")
    append_jsonl(sp.log, {"ts": now(), "event": "report_rendered", "detail": {"findings": len(rows)}})
    out = {"success": True, "path": str(sp.report), "findings": len(rows), "lines": len(lines), "chars": len(md),
           "rows": {g: len(_collapse_offers(by[g])) if g == "marketplace" else len(by[g]) for g in by},
           "picks": [pk.get("model") for pk in picks], "others": len(others)}
    if full:
        out["markdown"] = md
    return out


def add_followup(topic: str, session: str, title: str, question: str, answer_md: str) -> dict:
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    sp.followups.mkdir(exist_ok=True)
    n = len(list(sp.followups.glob("*.md"))) + 1
    fp = sp.followups / f"{n:02d}_{slugify(title)}.md"
    fp.write_text(f"# {title}\n\n_{now()[:16].replace('T', ' ')}_\n\n**Вопрос:** {question}\n\n{answer_md}\n", encoding="utf-8")
    append_jsonl(sp.log, {"ts": now(), "event": "followup_added", "detail": {"file": fp.name, "title": title}})
    render(topic, session)
    return {"success": True, "path": str(fp), "report": str(sp.report)}
