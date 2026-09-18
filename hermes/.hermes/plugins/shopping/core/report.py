"""Layer 3 — presentation: render report.md and follow-up files from session state. Pure: reads state, writes md."""
from __future__ import annotations

from typing import Any

from .findings import model_key
from .fs import append_jsonl, now, read_jsonl, slugify
from .model import GEO_LABEL
from . import sessions

MD_TABLE_HEAD: tuple[str, ...] = ("| # | Модель | Цена | Магазин | Рейтинг | Нюансы по отзывам | Рассрочка | Гео | Продавец / наличие |",
                 "|---|---|---|---|---|---|---|---|---|")


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


def _offers_table(items: list[dict], reviews: dict[str, list[dict]]) -> list[str]:
    if not items:
        return ["_нет данных_", ""]
    items = sorted(_collapse_offers(items), key=lambda f: (f.get("price_uah") is None, f.get("price_uah") or 0))
    out = list(MD_TABLE_HEAD)
    shown: set[str] = set()
    for i, f in enumerate(items, 1):
        name = cell(f.get("title") or f.get("model"))
        if f.get("model") and f["model"] not in name:
            name += f" ({cell(f['model'])})"
        mk = model_key(f)
        if mk in shown:
            nuances_cell = "см. выше"
        else:
            shown.add(mk)
            nuances = list(f.get("nuances") or []) + list(f.get("cons") or [])
            for r in reviews.get(mk, []):
                nuances += r.get("nuances") or []
            nuances_cell = "; ".join(_dedupe(nuances)) or "—"
        geo = "UA" if f.get("delivery_scope") == "ua_local" else "доставка в UA"
        seller = " / ".join(x for x in (cell(f.get("seller")), cell(f.get("availability"))) if x) or "—"
        if f.get("_dups"):
            seller += f" (+{f['_dups']} дубл.)"
        out.append(f"| {i} | {name} | {cell(fmt_price(f))} | {link(f)} | {cell(fmt_rating(f))} | "
                   f"{cell(nuances_cell)} | {cell(fmt_installment(f))} | {geo} | {seller} |")
    return out + [""]


def _aggregator_table(aggs: list[dict]) -> list[str]:
    if not aggs:
        return ["_нет данных_", ""]
    out = ["| Модель | Агрегатор | Цена мин – макс | Предложений | Рейтинг |", "|---|---|---|---|---|"]
    for f in sorted(aggs, key=lambda f: (model_key(f), f.get("source", ""))):
        out.append(f"| {cell(f.get('model') or f.get('title'))} | {link(f)} | {cell(fmt_price(f))} | "
                   f"{cell(f.get('offers_count') or '—')} | {cell(fmt_rating(f))} |")
    return out + [""]


def _reviews_block(reviews: dict[str, list[dict]]) -> list[str]:
    if not reviews:
        return ["_отзывы ещё не собраны_", ""]
    out = []
    for key in sorted(reviews):
        rs = reviews[key]
        out.append(f"### {cell(rs[0].get('model') or rs[0].get('title'))}")
        for r in rs:
            match = f" · совпадение модели: {r['model_match']}" if r.get("model_match") else ""
            out.append(f"- {link(r, r.get('source') or 'источник')}{match}")
            out += [f"  - ⚠ {n}" for n in r.get("nuances") or []]
            out += [f"  - ＋ {n}" for n in r.get("pros") or []]
            if r.get("notes"):
                out.append(f"  - {r['notes']}")
        out.append("")
    return out


def _summary_block(s: dict) -> list[str]:
    if not s:
        return []
    out = ["## 5. Итог", ""]
    if s.get("verdict"):
        out += [s["verdict"], ""]
    for pk in s.get("picks") or []:
        out.append(f"- **{pk.get('model', '')}** — {pk.get('why', '')}" + (f" ({pk['url']})" if pk.get("url") else ""))
    if s.get("caveats"):
        out += ["", "Оговорки:"] + [f"- {c}" for c in s["caveats"]]
    return out + [""]


def _followups_block(sp) -> list[str]:
    files = sorted(sp.followups.glob("*.md")) if sp.followups.exists() else []
    if not files:
        return []
    out = ["## 6. Уточнения", ""]
    for fp in files:
        first = fp.read_text(encoding="utf-8").splitlines()[0].lstrip("# ").strip() if fp.stat().st_size else fp.stem
        out.append(f"- [{cell(first)}](followups/{fp.name})")
    return out + [""]


def render(topic: str, session: str, full: bool = False) -> dict:
    """Write report.md. Returns a compact summary (path, sizes, picks) — the markdown itself only
    when `full=True`; the agent shows the file to the user via read_file, not from the tool result."""
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    rows = read_jsonl(sp.findings)
    by = {g: [f for f in rows if f["group"] == g] for g in ("marketplace", "shop", "aggregator", "review")}
    reviews: dict[str, list[dict]] = {}
    for f in by["review"]:
        reviews.setdefault(model_key(f), []).append(f)
    p = meta["params"]
    lines = [f"# {meta['topic']}: {p['query']}", "",
             f"Сессия `{meta['id']}` · статус: {meta['status']} · обновлено: {meta['updated'][:16].replace('T', ' ')}", "",
             "## Параметры поиска", "", *_params_block(p), "",
             "## 1. Маркетплейсы", "", *_offers_table(by["marketplace"], reviews),
             "## 2. Магазины", "", *_offers_table(by["shop"], reviews),
             "## 3. Агрегаторы цен (где выгоднее)", "", *_aggregator_table(by["aggregator"]),
             "## 4. Отзывы и нюансы по моделям", "", *_reviews_block(reviews),
             *_summary_block(meta.get("summary") or {}),
             *_followups_block(sp)]
    md = "\n".join(lines)
    sp.report.write_text(md, encoding="utf-8")
    append_jsonl(sp.log, {"ts": now(), "event": "report_rendered", "detail": {"findings": len(rows)}})
    out = {"success": True, "path": str(sp.report), "findings": len(rows), "lines": len(lines), "chars": len(md),
           "rows": {g: len(_collapse_offers(by[g])) if g in ("marketplace", "shop") else len(by[g]) for g in by},
           "picks": [pk.get("model") for pk in (meta.get("summary") or {}).get("picks") or []]}
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
