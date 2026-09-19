"""Adapter — Hermes tool handlers: (args: dict, **kw) -> JSON string over the core API."""
from __future__ import annotations

import json
import logging
from collections.abc import Callable

from . import core

logger = logging.getLogger(__name__)


def _json(fn: Callable, *keys: str):
    """Pick `keys` from args (or pass all when no keys) and call core.fn(**picked)."""
    def handler(args: dict, **kw) -> str:
        del kw
        try:
            call = {k: args[k] for k in keys if k in args} if keys else dict(args)
            return json.dumps(fn(**call), ensure_ascii=False)
        except Exception as e:  # a plugin bug must surface as a tool error, not kill the turn
            logger.exception("shopping tool %s failed", getattr(fn, "__name__", fn))
            return json.dumps({"success": False, "error": f"{type(e).__name__}: {e}"}, ensure_ascii=False)
    return handler


def _update_params(args: dict, **kw) -> str:
    del kw
    a = dict(args)
    topic, session, status = a.pop("topic", None), a.pop("session", None), a.pop("status", None)
    return json.dumps(core.update_params(topic, session, status=status, **a), ensure_ascii=False)


HANDLERS: dict[str, Callable[..., str]] = {
    "shop_list_topics": _json(core.list_topics),
    "shop_create_topic": _json(core.create_topic, "slug", "title"),
    "shop_list_sessions": _json(core.list_sessions, "topic"),
    "shop_create_session": _json(core.create_session, "topic", "query", "purpose", "must", "nice", "extra",
                                 "geo", "budget_uah", "notes", "slug", "sites"),
    "shop_get_session": _json(core.get_session, "topic", "session", "log_tail"),
    "shop_update_params": _update_params,
    "shop_add_findings": _json(core.add_findings, "topic", "session", "findings"),
    "shop_list_findings": _json(core.list_findings, "topic", "session", "group", "model", "fields"),
    "shop_log": _json(core.log_event, "topic", "session", "event", "detail"),
    "shop_set_summary": _json(core.set_summary, "topic", "session", "verdict", "picks", "caveats", "status"),
    "shop_render_report": _json(core.render_report, "topic", "session", "full"),
    "shop_add_followup": _json(core.add_followup, "topic", "session", "title", "question", "answer_md"),
    "shop_sources": _json(core.get_sources, "group", "query"),
    "shop_catalog": _json(core.fetch_catalog, "topic", "session", "section", "filter_ids", "want", "max_pages"),
    "shop_fetch": _json(core.fetch_site, "topic", "session", "site", "model", "geo", "limit", "category"),
    "shop_probe": _json(core.probe_sites_search, "query", "exclude", "only"),
    "shop_reviews": _json(core.collect_reviews, "topic", "session", "model", "sites"),
    "shop_resolve": _json(core.resolve_reference, "reference"),
}


def _menu(args: dict, **kw) -> str:
    """shop_menu: build the list in core.menus, render it via ui (host panel), return values."""
    del kw
    from . import ui
    try:
        kind = args.get("kind")
        pr = None
        if kind == "topics":
            menu = core.menus.topics_menu()
        elif kind == "sessions":
            menu = core.menus.sessions_menu(args["topic"])
        elif kind == "mode":
            menu = core.menus.mode_menu(args.get("query") or "")
        elif kind == "condition":
            menu = core.menus.condition_menu()
        elif kind == "probe":
            menu = core.menus.probe_menu()
        elif kind == "sources":
            if args.get("query") and args.get("probe", True):
                pr = core.probe_sites_search(args["query"], exclude=args.get("exclude"), only=args.get("only"))
            menu = core.menus.sources_menu(pr, exclude=args.get("exclude"))
        elif kind == "candidates":
            menu = core.menus.candidates_menu(args.get("candidates") or [])
        elif kind == "reviews":
            menu = core.menus.reviews_menu()
        else:
            return json.dumps({"success": False, "error": f"unknown menu kind {kind!r}"})
        res = ui.ask(menu)
        if kind == "probe":
            res.update(core.menus.probe_selection(res["values"]))
        if pr:
            res["probe"] = {s["site"]: (s.get("total_est") or s.get("hits")) for s in pr["sites"] if s.get("probed")}
        return json.dumps(res, ensure_ascii=False)
    except ui.NoUI as e:
        return json.dumps({"success": False, "error": f"no_ui: {e}",
                           "fallback": "ask the user in plain text with a numbered list"}, ensure_ascii=False)
    except Exception as e:  # noqa: BLE001
        logger.exception("shop_menu failed")
        return json.dumps({"success": False, "error": f"{type(e).__name__}: {e}"}, ensure_ascii=False)


HANDLERS["shop_menu"] = _menu


START_PROMPT = (
    "Загрузи скилл shopping-research (skill_view) и веди меня по его процедуре с шага 1: "
    "тема → сессия → тип поиска → бриф → зонд → источники → (кандидаты) → поиск → отзывы → отчёт. "
    "Все списки — через shop_menu; свободные поля спрашивай по одному. Начинай."
)


def make_slash_shop(inject) -> Callable[[str], str]:
    """/shop → start the guided flow (injects the start prompt as a user turn);
    /shop status [topic] [session] → state without spending model turns."""
    def slash_shop(raw_args: str) -> str:
        parts = raw_args.split()
        if not parts or parts[0] in ("start", "new"):
            return "Запускаю поиск…" if inject(START_PROMPT) else "Не удалось запустить (нет активной сессии чата)."
        if parts[0] == "status":
            parts = parts[1:]
        return _status(parts)
    return slash_shop


def _status(parts: list[str]) -> str:
    if not parts:
        t = core.list_topics()
        if not t["topics"]:
            return f"Тем нет. Корень: {t['root']}"
        return "\n".join(f"{x['slug']:<20} {x['sessions']} сессий, последняя {x['last_session'] or '—'}"
                         for x in t["topics"])
    if len(parts) == 1:
        s = core.list_sessions(parts[0])
        if not s.get("success"):
            return s["error"]
        return "\n".join(f"{x['id']:<32} {x['status']:<9} {x['findings']:>3} находок  {x['query'] or ''}"
                         for x in s["sessions"]) or "сессий нет"
    g = core.get_session(parts[0], parts[1])
    if not g.get("success"):
        return g["error"]
    return json.dumps({k: g[k] for k in ("path", "findings_total", "findings_by_group", "models", "report_path")},
                      ensure_ascii=False, indent=1)
