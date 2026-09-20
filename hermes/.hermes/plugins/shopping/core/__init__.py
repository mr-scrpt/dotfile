"""Public API of the shopping core — the only surface adapters (tools, CLI, slash) import.

Layers: fs (io) → http/model → sources/<key>/ (declarative site packages) → catalog (config view)
→ sessions/findings/fetch/probe (state, services)
→ report/menus (presentation; menus are pure data — the UI adapter lives outside core).
"""
from .catalog import get as get_sources
from .candidates import discover as find_candidates
from .compare import build as build_comparison
from . import recon as recon_mod
from .throttle import state as fetch_state
from .plans import capabilities as source_capabilities, probe_plans, run as run_plans, sample as sample_source
from .fetch import fetch as fetch_site
from . import menus, sessions, sources
from .probe import probe as probe_sites_search, sites as probe_sites
from .reviews import collect as collect_reviews
from .resolve import resolve as resolve_reference
from .findings import add as add_findings, list_ as list_findings, resume_context as get_session
from .model import GEO, GROUPS, STATUSES
from .report import add_followup, render as render_report
from .sessions import (create_session, create_topic, list_sessions, list_topics, log_event,
                       set_summary, update_params)

__all__ = ["GEO", "GROUPS", "STATUSES", "get_sources", "add_findings", "list_findings", "get_session",
           "add_followup", "render_report", "create_session", "create_topic", "list_sessions",
           "list_topics", "log_event", "set_summary", "update_params",
           "find_candidates", "build_comparison", "recon_mod", "fetch_state", "source_capabilities", "sample_source", "probe_plans", "run_plans", "fetch_site", "probe_sites_search", "probe_sites", "menus", "sources", "collect_reviews"]
