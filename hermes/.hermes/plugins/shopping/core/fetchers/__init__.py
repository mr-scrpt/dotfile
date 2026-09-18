"""Site fetchers — each module turns raw site responses into `finding`-shaped dicts.

Contract (every fetcher module):
    SITE: str                                  # key in sources.yaml
    GROUP: "marketplace" | "shop" | "aggregator"
    def search(query: str) -> list[dict]       # offers/cards matching a free-text query (network)
    def parse_search(raw: str) -> list[dict]   # pure: same, from saved text (tests)
Optional:
    def card(url: str) -> dict                 # offer detail + reviews (network)
    def parse_card(...) -> dict                # pure counterpart
    def catalog(spec: dict) -> list[dict]      # aggregators: structured category walk (network)

Returned dicts use the findings schema keys only (group, source, title, model, url, price_uah,
price_min_uah, price_max_uah, rating, rating_count, offers_count, availability, seller,
delivery_scope, installment, installment_note, nuances, notes). `model` is left for the caller
to normalise; fetchers do not guess model codes beyond what the page states.
"""
from __future__ import annotations

from importlib import import_module

REGISTRY = {"hotline": "hotline", "rozetka": "rozetka", "foxtrot": "foxtrot", "moyo": "moyo", "allo": "allo"}


def get(site: str):
    if site not in REGISTRY:
        raise KeyError(f"no fetcher for {site!r}; scripted sites: {sorted(REGISTRY)}")
    return import_module(f"{__name__}.{REGISTRY[site]}")


def available() -> list[str]:
    return sorted(REGISTRY)
