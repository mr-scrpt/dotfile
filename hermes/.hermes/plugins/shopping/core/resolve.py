"""Layer 2 — resolve: turn a reference (product URL or a model name) into a compact description
of the owned device: title, source, url, category path, characteristics. Used by the `reference`
search mode; the model then derives briefs for what has to be bought (inverter, charger…) from
`spec` and shows them to the user for confirmation.

Only sites with a `card(url) -> {title, category_path, spec}` function in their fetcher can resolve
URLs; names are resolved through hotline search (title + notes) with no characteristics table.
"""
from __future__ import annotations

import re
from urllib.parse import urlparse

from . import sources
from .fs import err
from .http import FetchError

MAX_SPEC_VALUE = 160


def site_for_url(url: str) -> str | None:
    host = (urlparse(url).hostname or "").lower().removeprefix("www.")
    for s in sources.all_sources():
        if host == s.host or host.endswith("." + s.host):
            return s.key
    return None


def _trim_spec(spec: dict) -> dict:
    return {k: (v[:MAX_SPEC_VALUE] + "…" if len(v) > MAX_SPEC_VALUE else v) for k, v in spec.items() if v}


def resolve(reference: str) -> dict:
    """URL → site card; else hotline search by name. Never raises."""
    ref = (reference or "").strip()
    if not ref:
        return err("reference must not be empty")
    if re.match(r"https?://", ref):
        site = site_for_url(ref)
        if not site:
            return err(f"no source for {urlparse(ref).hostname!r}; give the model name instead")
        mod = sources.get(site).module()
        if not hasattr(mod, "card"):
            return err(f"{site} cannot read product cards yet; give the model name instead")
        try:
            card = mod.card(ref)
        except FetchError as e:
            return err(f"{site}: {e}")
        return {"success": True, "reference": {"source": site, "url": ref, "title": card.get("title", ""),
                                               "category_path": card.get("category_path") or [],
                                               "spec": _trim_spec(card.get("spec") or {})}}
    try:
        hits = sources.get("hotline").module().search(ref)
    except FetchError as e:
        return err(f"hotline: {e}")
    if not hits:
        return err(f"nothing on hotline for {ref!r}; give a product URL instead")
    h = hits[0]
    spec = {}
    for part in (h.get("notes") or "").split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            spec[k.strip()] = v.strip()
    return {"success": True, "reference": {"source": "hotline", "url": h["url"], "title": h["title"],
                                           "category_path": [], "spec": spec},
            "alternatives": [x["title"] for x in hits[1:4]]}
