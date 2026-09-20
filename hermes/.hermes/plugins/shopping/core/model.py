"""Layer 1 — domain constants and the on-disk layout of a session. Everything above imports from here."""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from .fs import root

GROUPS = ("marketplace", "aggregator", "review")   # "shop" merged into marketplace: small shops come via aggregators
GEO = ("ua_local", "ua_delivery")
STATUSES = ("draft", "searching", "done")
REVIEW_MODES = ("none", "cards", "full")
MODES = ("exact", "spec", "reference")       # exact: one known model · spec: pick by parameters · reference: pick for an owned device
CONDITIONS = ("new", "any")                  # new: drop б/у, відновлений, refurbished cards
MODE_LABEL = {"exact": "конкретная модель (напр. iPhone 17 Pro 256)",
              "spec": "подбор по параметрам (напр. монитор 27\" 100+ Гц 2K+)",
              "reference": "подбор под имеющееся устройство (ссылка или название образца + что нужно)"}
GEO_LABEL = {"ua_local": "только Украина (локальный склад)",
             "ua_delivery": "с доставкой в Украину (вкл. Rozetka EU)"}

SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
SESSION_RE = re.compile(r"^\d{4}-\d{2}-\d{2}(_[a-z0-9-]+)?(-\d+)?$")


def default_params() -> dict:
    return {"query": "", "purpose": "", "must": [], "nice": [], "extra": [], "geo": "ua_local", "budget_uah": None,
            "notes": "", "sites": [], "category": "",
            "reviews": "cards",      # none | cards (buyer reviews from chosen sites) | full (cards + web reviews)
            "mode": "spec",          # exact | spec | reference — chosen by the user in the first menu
            "condition": "new",      # new | any
            "reference": None,       # reference mode: {"title", "url", "source", "spec": {...}} of the owned device
            "items": [],             # reference mode with several wanted things: [{"name": "инвертор", "must": [...]}, ...]
            "shortlist": [],         # models that passed the criteria and go to offers+reviews
            "criteria": [],          # criteria authored from `observed` and confirmed by the user (core.spec format)
            "recon": None}           # topic research result (terms/variants/quality/criteria), see core.recon


@dataclass(frozen=True)
class SessionPaths:
    topic: str
    session: str

    @property
    def dir(self) -> Path:
        return root() / self.topic / self.session

    @property
    def meta(self) -> Path:
        return self.dir / "search.json"

    @property
    def findings(self) -> Path:
        return self.dir / "findings.jsonl"

    @property
    def log(self) -> Path:
        return self.dir / "log.jsonl"

    @property
    def report(self) -> Path:
        return self.dir / "report.md"

    @property
    def followups(self) -> Path:
        return self.dir / "followups"


def topic_dir(topic: str) -> Path:
    return root() / topic
