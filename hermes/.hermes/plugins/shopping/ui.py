"""Adapter — interactive menus rendered by the host's own choice panel.

This is the ONLY module that talks to the UI. It calls the platform clarify *callback* directly
(`callback(question, choices, multi_select) -> str`), the same function Hermes injects into the
model's `clarify` tool — but bypasses that tool, so the tool's 4-choice cap and its
"(Recommended)" label never apply. The CLI panel supports arrows, 1-9/0 keys, Space checkboxes and
an "Other" free-text row for any list length; the gateway renders buttons / a numbered list.

Where the callback comes from: the agent bound to the interactive CLI (`PluginManager._cli_ref.agent`).
Gateway sessions have no `_cli_ref`; until upstream exposes an accessor, `shop_menu` there reports
`no_ui` and the skill falls back to a numbered question in chat.

Answer wire format (host contract): single-select → the chosen label (or typed text); multi-select
→ labels joined with ", " (typed text appended). Labels therefore never contain a comma.
"""
from __future__ import annotations

from .core import menus


class NoUI(RuntimeError):
    """No interactive choice panel reachable in this process."""


def resolve_clarify_callback():
    try:
        from hermes_cli.plugins import get_plugin_manager
        cli = getattr(get_plugin_manager(), "_cli_ref", None)
        agent = getattr(cli, "agent", None)
        cb = getattr(agent, "clarify_callback", None)
    except Exception:  # noqa: BLE001 — hermes internals unavailable (tests, CLI script)
        cb = None
    return cb if callable(cb) else None


def _show(callback, question: str, choices: list[str], multi: bool):
    try:
        return callback(question, choices, multi_select=multi)
    except TypeError:  # older callbacks without the kwarg
        return callback(question, choices)


def ask(menu: dict, callback=None) -> dict:
    """Render `menu` (see core.menus) once; returns {"values": [...], "free_text": str|None}."""
    cb = callback or resolve_clarify_callback()
    if cb is None:
        raise NoUI("no interactive UI in this process (gateway / headless)")
    choices = [c["label"] for c in menu["items"]]
    raw = _show(cb, menu["question"], choices, bool(menu["multi"]))
    parsed = menus.parse_answer(menu, raw)
    return {"success": True, "values": parsed["values"], "free_text": parsed["free_text"]}
