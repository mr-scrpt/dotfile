"""Layer 3 — menus: pure builders for interactive choice lists (no UI, no network).

A menu is `{"question": str, "items": [{"value": str, "label": str, ...}], "multi": bool}`.
Labels never contain a comma (the host joins multi-select answers with ", "). `parse_answer()`
maps the host's raw answer back to item values; anything unmatched is free text ("Other").
"""
from __future__ import annotations

import re

from . import probe, sessions

NEW_TOPIC = "__new_topic__"
NEW_SESSION = "__new_session__"


def _n(v) -> str:
    return f"{v:,}".replace(",", " ") if isinstance(v, int) else "—"


def _label(s: str) -> str:
    return s.replace(",", ";")


# ------------------------------------------------------------------ builders
def topics_menu() -> dict:
    items = [{"value": t["slug"], "label": _label(f"{t['slug']} — {t['sessions']} сесс. · последняя {t['last_session'] or '—'}")}
             for t in sessions.list_topics()["topics"]]
    items.append({"value": NEW_TOPIC, "label": "новая тема"})
    return {"question": "Тема поиска", "items": items, "multi": False}


def sessions_menu(topic: str) -> dict:
    r = sessions.list_sessions(topic)
    items = [{"value": s["id"], "label": _label(f"{s['id']} · {s['status']} · {s['findings']} нах. · {(s['query'] or '')[:40]}")}
             for s in reversed(r.get("sessions") or [])]
    items.append({"value": NEW_SESSION, "label": "новый поиск"})
    return {"question": f"Тема «{topic}»: продолжить сессию или начать новую?", "items": items, "multi": False}


PROBE_ALL = "__all__"
PROBE_SKIP = "__skip__"


def probe_menu() -> dict:
    """One screen: every probe-able site listed by name. Tick "все" or individual sites to probe
    them; "без зонда" (or nothing) skips straight to the source choice."""
    scripted = [s for s in probe.sites() if s["scripted"]]
    items = [{"value": PROBE_ALL, "label": f"все {len(scripted)} источников"}]
    items += [{"value": s["site"], "label": _label(s["title"]), "group": s["group"]} for s in scripted]
    items.append({"value": PROBE_SKIP, "label": "без зонда — сразу выбрать источники"})
    return {"question": "Зонд (~5 с; без токенов на страницы): по каким источникам проверить количество позиций? "
                        "Пробел — отметить; Enter — подтвердить", "items": items, "multi": True}


def probe_selection(values: list[str]) -> dict:
    """Menu answer → {"probe": bool, "only": [...]|None}."""
    if not values or PROBE_SKIP in values:
        return {"probe": False, "only": None}
    if PROBE_ALL in values:
        return {"probe": True, "only": None}
    return {"probe": True, "only": [v for v in values if v not in (PROBE_ALL, PROBE_SKIP)]}


MENU_CATS = 3            # categories shown inline per site


def _hits_tag(n: int, r: dict) -> str:
    """'246 телефонов · 1400 чехлов · 543 стёкол' when the site reports categories, else the total."""
    cats = [c for c in r.get("categories") or [] if c.get("count")]
    if not cats:
        return f"{_n(n)}{'+' if r.get('total_est') and (r.get('hits') or 0) < n else ''}"
    parts = [f"{_n(c['count'])} {c['name'].lower()}" for c in cats[:MENU_CATS]]
    rest = len(cats) - MENU_CATS
    return " · ".join(parts) + (f" · +{rest}" if rest > 0 else "")


STATUS_TAG = {"excluded": "исключён из зонда", "no_script": "нет скрипта — только браузер",
              "not_probed": "не зондировался", "error": "ошибка зонда", "zero": "0 — не найдено"}


def sources_menu(probe_result: dict | None = None, exclude: list[str] | None = None) -> dict:
    """One flat list, every source visible with an explicit state. With a probe: hits first (most
    first), then excluded / no-script / errors, then zero-hit sites. Without a probe: catalogue order,
    browser sites tagged."""
    by = {s["site"]: s for s in (probe_result or {}).get("sites", [])}
    rows = []
    for s in probe.sites(exclude):
        r = by.get(s["site"])
        if not probe_result:
            rows.append((0, 0, s, "" if s["scripted"] else "браузер"))
            continue
        status = (r or {}).get("status") or ("no_script" if not s["scripted"] else "not_probed")
        if status == "hits":
            n = r.get("total_est") or r["hits"]
            rows.append((0, -n, s, _hits_tag(n, r)))
        else:
            rows.append((2 if status == "zero" else 1, 0, s, STATUS_TAG[status]))
    rows.sort(key=lambda x: (x[0], x[1]))
    items = [{"value": s["site"], "label": _label(f"{s['title']} ({tag})" if tag else s["title"]), "group": s["group"]}
             for _, _, s, tag in rows]
    q = "Где искать? (в скобках — что нашёл зонд: по категориям, если сайт их отдаёт)" if probe_result else "Где искать?"
    return {"question": q, "items": items, "multi": True}


def candidates_menu(candidates: list[dict]) -> dict:
    items = [{"value": c["model"], "label": _label(f"{c['model']} · {_n(c.get('price_min_uah'))}–{_n(c.get('price_max_uah'))} ₴ · {c.get('offers') or 0} предл.")}
             for c in candidates]
    return {"question": "Какие модели сравнивать подробно?", "items": items, "multi": True}


# ------------------------------------------------------------------ parsing
def parse_answer(menu: dict, answer) -> dict:
    """Host answer (str | list) → {values, free_text}. Multi-select strings are ", "-joined labels;
    every token that is not a known label is free text."""
    by_label = {c["label"]: c["value"] for c in menu["items"]}
    if isinstance(answer, list):
        tokens = [str(a) for a in answer]
    else:
        raw = (answer or "").strip()
        tokens = [t for t in re.split(r",\s*", raw)] if menu["multi"] and raw else [raw]
    values, free = [], []
    for t in tokens:
        t = t.strip()
        if not t:
            continue
        if t in by_label:
            values.append(by_label[t])
        else:
            free.append(t)
    return {"values": values, "free_text": ", ".join(free) or None}
