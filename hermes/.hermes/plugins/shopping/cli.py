#!/usr/bin/env python3
"""CLI adapter over the shopping core — for subagents and manual use. JSON on stdout, exit 1 on error.

Usage:
  cli.py list-topics
  cli.py create-topic SLUG [--title T]
  cli.py list-sessions TOPIC
  cli.py create-session TOPIC --query Q [--must A]... [--nice B]... [--extra C]... [--geo ua_local|ua_delivery] [--budget N] [--notes S] [--slug S]
  cli.py get-session TOPIC SESSION
  cli.py add-findings TOPIC SESSION (--json '[...]' | --file findings.json | <stdin>)
  cli.py list-findings TOPIC SESSION [--group G] [--model M]
  cli.py log TOPIC SESSION EVENT [DETAIL]
  cli.py render TOPIC SESSION
  cli.py sources [--group G] [--query Q]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))  # import as package: shopping.core
from shopping import core  # noqa: E402


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list-topics")
    p = sub.add_parser("create-topic"); p.add_argument("slug"); p.add_argument("--title")
    p = sub.add_parser("list-sessions"); p.add_argument("topic")
    p = sub.add_parser("create-session"); p.add_argument("topic"); p.add_argument("--query", required=True)
    p.add_argument("--purpose", required=True)
    p.add_argument("--must", action="append", default=[]); p.add_argument("--nice", action="append", default=[])
    p.add_argument("--extra", action="append", default=[]); p.add_argument("--geo", default="ua_local", choices=core.GEO)
    p.add_argument("--budget", type=int); p.add_argument("--notes", default=""); p.add_argument("--slug")
    p = sub.add_parser("get-session"); p.add_argument("topic"); p.add_argument("session")
    p = sub.add_parser("add-findings"); p.add_argument("topic"); p.add_argument("session")
    p.add_argument("--json"); p.add_argument("--file")
    p = sub.add_parser("list-findings"); p.add_argument("topic"); p.add_argument("session")
    p.add_argument("--group", choices=core.GROUPS); p.add_argument("--model")
    p = sub.add_parser("log"); p.add_argument("topic"); p.add_argument("session"); p.add_argument("event")
    p.add_argument("detail", nargs="?")
    p = sub.add_parser("render"); p.add_argument("topic"); p.add_argument("session")
    p = sub.add_parser("sources"); p.add_argument("--group"); p.add_argument("--query")
    p = sub.add_parser("fetch"); p.add_argument("topic"); p.add_argument("session"); p.add_argument("site"); p.add_argument("model")
    p.add_argument("--category", default=None)
    p.add_argument("--geo", default="ua_local", choices=core.GEO); p.add_argument("--limit", type=int, default=5)
    p = sub.add_parser("catalog"); p.add_argument("topic"); p.add_argument("session"); p.add_argument("section")
    p.add_argument("filter_ids", type=int, nargs="+"); p.add_argument("--want", help="JSON: {diagonal_in:[lo,hi],panel_any:[..],resolution:'',refresh_min:N}")
    p = sub.add_parser("hotline-filters"); p.add_argument("section")
    p = sub.add_parser("probe", help="parallel hit-count probe on scripted sites"); p.add_argument("query")
    p.add_argument("--exclude", nargs="*", default=None); p.add_argument("--only", nargs="*", default=None)
    p.add_argument("--table", action="store_true", help="human table instead of JSON")
    return ap


def run(a: argparse.Namespace) -> dict:
    if a.cmd == "list-topics":
        return core.list_topics()
    if a.cmd == "create-topic":
        return core.create_topic(a.slug, a.title)
    if a.cmd == "list-sessions":
        return core.list_sessions(a.topic)
    if a.cmd == "create-session":
        return core.create_session(a.topic, a.query, a.purpose, a.must, a.nice, a.extra, a.geo, a.budget, a.notes, a.slug)
    if a.cmd == "get-session":
        return core.get_session(a.topic, a.session)
    if a.cmd == "add-findings":
        raw = a.json or (Path(a.file).read_text(encoding="utf-8") if a.file else sys.stdin.read())
        return core.add_findings(a.topic, a.session, json.loads(raw))
    if a.cmd == "list-findings":
        return core.list_findings(a.topic, a.session, a.group, a.model)
    if a.cmd == "log":
        return core.log_event(a.topic, a.session, a.event, a.detail)
    if a.cmd == "render":
        out = core.render_report(a.topic, a.session)
        out.pop("markdown", None)
        return out
    if a.cmd == "fetch":
        return core.fetch_site(a.topic, a.session, a.site, a.model, a.geo, a.limit, category=a.category)
    if a.cmd == "catalog":
        return core.fetch_catalog(a.topic, a.session, a.section, a.filter_ids, json.loads(a.want) if a.want else None)
    if a.cmd == "hotline-filters":
        return core.hotline_filters(a.section)
    if a.cmd == "probe":
        return core.probe_sites_search(a.query, a.exclude, a.only)
    return core.get_sources(a.group, a.query)


def _probe_table(out: dict) -> str:
    rows = []
    for s in out["sites"]:
        n = s.get("total_est") or s.get("hits")
        tag = {"hits": f"{n}", "zero": "0", "error": s.get("error"), "excluded": "исключён", "no_script": "нет скрипта", "not_probed": "не зондировался"}[s["status"]]
        cats = " · ".join(f"{c['count'] or '?'} {c['name'][:24]}" for c in s.get("categories", [])[:4])
        smp = "; ".join(f"{x['title'][:38]} {x['price_uah'] or ''}".strip() for x in s.get("sample", [])[:2])
        rows.append(f"{s['site']:<10} {s['group']:<12} {tag:<14} {cats or smp}")
    return "\n".join(rows)


def main(argv=None) -> int:
    a = build_parser().parse_args(argv)
    out = run(a)
    if getattr(a, "table", False) and out.get("success"):
        print(_probe_table(out))
        return 0
    print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0 if out.get("success", True) else 1


if __name__ == "__main__":
    sys.exit(main())
