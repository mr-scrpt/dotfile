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


def probe_menu(sites_total: int) -> dict:
    return {"question": f"Сделать зонд по {sites_total} script-источникам (~5 с; без токенов на страницы)?",
            "items": [{"value": "probe", "label": "да — зонд по всем"},
                      {"value": "probe_exclude", "label": "зонд — но кое-что исключить"},
                      {"value": "skip", "label": "нет — сразу выбрать источники"}], "multi": False}


def sources_menu(probe_result: dict | None = None, exclude: list[str] | None = None) -> dict:
    """One flat list. With a probe: sites with hits first (most hits first), then unprobed browser
    sites; zero-hit sites are dropped and named in the question. Without a probe: catalogue order."""
    by = {s["site"]: s for s in (probe_result or {}).get("sites", [])}
    hit, unprobed, zero = [], [], []
    for s in probe.sites(exclude):
        r = by.get(s["site"])
        if not probe_result:
            hit.append((0, s, "" if s["scripted"] else "браузер"))
        elif r is None or not r.get("probed"):
            unprobed.append((0, s, "без зонда"))
        elif r.get("error"):
            unprobed.append((0, s, "ошибка"))
        elif r.get("hits"):
            n = r.get("total_est") or r["hits"]
            hit.append((n, s, f"{_n(n)}{'+' if r.get('total_est') and r['hits'] < n else ''}"))
        else:
            zero.append(s["title"])
    if probe_result:
        hit.sort(key=lambda x: -x[0])
    items = [{"value": s["site"], "label": _label(f"{s['title']} ({tag})" if tag else s["title"]), "group": s["group"]}
             for _, s, tag in hit + unprobed]
    q = "Где искать? (в скобках — найдено позиций)" if probe_result else "Где искать?"
    if zero:
        q += " · 0 находок: " + ", ".join(zero)
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
