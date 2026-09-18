"""Layer 2 — topics and sessions: create / list / load / update params / journal."""
from __future__ import annotations

from datetime import date
from typing import Any

from .fs import append_jsonl, err, now, read_json, read_jsonl, root, slugify, write_json
from .model import GEO, SESSION_RE, SLUG_RE, STATUSES, SessionPaths, default_params, topic_dir


# ------------------------------------------------------------------ topics
def list_topics() -> dict:
    r = root()
    r.mkdir(parents=True, exist_ok=True)
    topics = []
    for d in sorted(r.iterdir()):
        if not d.is_dir() or d.name.startswith("."):
            continue
        meta = read_json(d / "topic.json", {}) or {}
        sessions = [s.name for s in sorted(d.iterdir()) if s.is_dir() and SESSION_RE.match(s.name)]
        topics.append({"slug": d.name, "title": meta.get("title", d.name),
                       "sessions": len(sessions), "last_session": sessions[-1] if sessions else None})
    return {"success": True, "root": str(r), "topics": topics}


def create_topic(slug: str, title: str | None = None) -> dict:
    slug = slug.strip().lower()
    if not SLUG_RE.match(slug):
        return err("slug must match [a-z0-9-], e.g. 'monitor', 'gpu', 'washing-machine'")
    d = topic_dir(slug)
    meta_p = d / "topic.json"
    if meta_p.exists():
        return {"success": True, "created": False, "topic": read_json(meta_p), "path": str(d)}
    d.mkdir(parents=True, exist_ok=True)
    meta = {"slug": slug, "title": title or slug, "created": now()}
    write_json(meta_p, meta)
    return {"success": True, "created": True, "topic": meta, "path": str(d)}


# ------------------------------------------------------------------ sessions
def load(topic: str, session: str) -> tuple[dict | None, SessionPaths]:
    sp = SessionPaths(topic, session)
    return read_json(sp.meta), sp


def not_found(topic: str, session: str) -> dict:
    return err(f"session {topic}/{session} not found")


def list_sessions(topic: str) -> dict:
    d = topic_dir(topic)
    if not d.is_dir():
        return err(f"topic {topic!r} does not exist", topics=list_topics()["topics"])
    out = []
    for s in sorted(d.iterdir()):
        if s.is_dir() and SESSION_RE.match(s.name):
            sp = SessionPaths(topic, s.name)
            meta = read_json(sp.meta, {}) or {}
            p = meta.get("params") or {}
            out.append({"id": s.name, "status": meta.get("status"), "query": p.get("query"), "geo": p.get("geo"),
                        "findings": len(read_jsonl(sp.findings)), "updated": meta.get("updated"),
                        "has_report": sp.report.exists()})
    return {"success": True, "topic": topic, "sessions": out}


def create_session(topic: str, query: str, must=None, nice=None, extra=None, geo: str = "ua_local",
                   budget_uah=None, notes: str = "", slug: str | None = None) -> dict:
    if not topic_dir(topic).is_dir():
        return err(f"topic {topic!r} does not exist — create it first")
    if geo not in GEO:
        return err(f"geo must be one of {GEO}")
    if not (query or "").strip():
        return err("query must not be empty")
    base = f"{date.today().isoformat()}_{slug or slugify(query)}"
    sid, n = base, 1
    while SessionPaths(topic, sid).dir.exists():
        n += 1
        sid = f"{base}-{n}"
    sp = SessionPaths(topic, sid)
    sp.followups.mkdir(parents=True, exist_ok=True)
    params = default_params() | {"query": query.strip(), "must": list(must or []), "nice": list(nice or []),
                                 "extra": list(extra or []), "geo": geo, "budget_uah": budget_uah, "notes": notes}
    meta = {"id": sid, "topic": topic, "created": now(), "updated": now(), "status": "draft",
            "params": params, "summary": {}}
    write_json(sp.meta, meta)
    append_jsonl(sp.log, {"ts": now(), "event": "created", "detail": params})
    return {"success": True, "session": meta, "path": str(sp.dir)}


def save(meta: dict, sp: SessionPaths, event: str | None = None, detail: Any = None) -> None:
    meta["updated"] = now()
    write_json(sp.meta, meta)
    if event:
        append_jsonl(sp.log, {"ts": now(), "event": event, "detail": detail})


def update_params(topic: str, session: str, status: str | None = None, **params) -> dict:
    meta, sp = load(topic, session)
    if meta is None:
        return not_found(topic, session)
    if status is not None and status not in STATUSES:
        return err(f"status must be one of {STATUSES}")
    changes = {k: v for k, v in params.items() if v is not None}
    unknown = [k for k in changes if k not in default_params()]
    if unknown:
        return err(f"unknown params {unknown}; allowed: {sorted(default_params())}")
    if changes.get("geo") not in (None, *GEO):
        return err(f"geo must be one of {GEO}")
    meta["params"].update(changes)
    if status:
        meta["status"] = status
        changes = changes | {"status": status}
    save(meta, sp, "params_updated", changes)
    return {"success": True, "session": meta}


def log_event(topic: str, session: str, event: str, detail: Any = None) -> dict:
    meta, sp = load(topic, session)
    if meta is None:
        return not_found(topic, session)
    row = {"ts": now(), "event": event, "detail": detail}
    append_jsonl(sp.log, row)
    return {"success": True, "logged": row}


def set_summary(topic: str, session: str, verdict: str = "", picks: list[dict] | None = None,
                caveats: list[str] | None = None, status: str | None = "done") -> dict:
    meta, sp = load(topic, session)
    if meta is None:
        return not_found(topic, session)
    if status and status not in STATUSES:
        return err(f"status must be one of {STATUSES}")
    meta["summary"] = {"verdict": verdict, "picks": picks or [], "caveats": caveats or [], "ts": now()}
    if status:
        meta["status"] = status
    save(meta, sp, "summary_set", {"picks": len(picks or [])})
    return {"success": True, "session": meta}
