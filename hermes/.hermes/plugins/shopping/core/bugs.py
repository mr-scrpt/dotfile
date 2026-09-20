"""Layer 1 — bugs: the plugin is a PRODUCT, so a running session reports defects instead of patching them.

An agent that "quickly fixes" the plugin mid-run is the worst outcome for a shipped tool: the user
gets an undocumented local mutation, the change is never reviewed or tested, and the next release
silently overwrites it. So when something in the plugin misbehaves during research, the agent files
a report here and keeps working around it (or stops and says so) — the fix happens later, in a
development session, by a human decision.

Reports live in `$SHOPPING_HOME/.bugs/` (outside any session, they outlive it): one markdown file
per report plus `index.jsonl` for listing.
"""
from __future__ import annotations

from pathlib import Path

from .fs import append_jsonl, now, read_jsonl, root, slugify

SEVERITIES = ("blocker", "degraded", "cosmetic")
TEMPLATE = """# {title}

- **Когда:** {ts}
- **Серьёзность:** {severity}
- **Версия плагина:** {version}
- **Инструмент / шаг:** {where}
- **Сессия:** {session}

## Что произошло
{observed}

## Что ожидалось
{expected}

## Как воспроизвести
{repro}

## Сообщение об ошибке
```
{error}
```

## Обходной путь, применённый в сессии
{workaround}
"""


def bugs_dir() -> Path:
    return root() / ".bugs"


def file_report(title: str, observed: str, expected: str = "", where: str = "", repro: str = "",
                error: str = "", severity: str = "degraded", workaround: str = "",
                topic: str = "", session: str = "", version: str = "") -> dict:
    """Record a defect found while using the plugin. Never modifies plugin code."""
    if not title.strip() or not observed.strip():
        return {"success": False, "error": "bugreport needs at least `title` and `observed`"}
    if severity not in SEVERITIES:
        return {"success": False, "error": f"severity must be one of {SEVERITIES}"}
    ts = now()
    rid = f"{ts[:10]}_{ts[11:16].replace(':', '')}-{slugify(title)}"
    path = bugs_dir() / f"{rid}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(TEMPLATE.format(
        title=title.strip(), ts=ts, severity=severity, version=version or "—",
        where=where or "—", session=f"{topic}/{session}" if topic or session else "—",
        observed=observed.strip(), expected=expected.strip() or "—", repro=repro.strip() or "—",
        error=(error or "—").strip(), workaround=workaround.strip() or "—"), encoding="utf-8")
    append_jsonl(bugs_dir() / "index.jsonl", {"id": rid, "ts": ts, "title": title.strip(),
                                              "severity": severity, "where": where,
                                              "session": f"{topic}/{session}" if topic else "",
                                              "status": "open", "path": str(path)})
    return {"success": True, "id": rid, "path": str(path), "severity": severity,
            "note": "багрепорт записан; НЕ чини плагин в этой сессии — скажи пользователю и, "
                    "если возможно, продолжи с обходным путём"}


def list_reports(status: str = "", limit: int = 20) -> dict:
    rows = read_jsonl(bugs_dir() / "index.jsonl")
    if status:
        rows = [r for r in rows if r.get("status") == status]
    rows = sorted(rows, key=lambda r: r.get("ts") or "", reverse=True)[:limit]
    return {"success": True, "count": len(rows), "dir": str(bugs_dir()), "reports": rows}
