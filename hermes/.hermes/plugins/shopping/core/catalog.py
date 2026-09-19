"""Layer 1 — shared search config (geo, reviews) + the read-only source catalogue view.

Sites themselves live in `core/sources/<key>/` (see that package). This module only merges the
two shared YAML files (bundled `data/*.yaml`, overridable by `~/shopping/.config/<name>.yaml`) and
presents everything to the model as one `shop_sources` document.
"""
from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import quote_plus

from . import sources
from .fs import err, root

DATA = Path(__file__).resolve().parent.parent / "data"
SHARED = ("geo", "reviews")


def _yaml(name: str) -> dict:
    import yaml
    user = root() / ".config" / f"{name}.yaml"
    p = user if user.is_file() else DATA / f"{name}.yaml"
    return (yaml.safe_load(p.read_text(encoding="utf-8")) or {}).get(name) or {}


def load() -> dict:
    doc = {name: _yaml(name) for name in SHARED}
    for group, label in (("aggregator", "aggregators"), ("marketplace", "marketplaces")):
        doc[label] = {s.key: s.public() for s in sources.all_sources() if s.group == group}
    return doc


def _fill(node, q: str, raw: str):
    if isinstance(node, dict):
        for k, v in node.items():
            node[k] = v.replace("{q}", q).replace("{model}", raw) if isinstance(v, str) else _fill(v, q, raw)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            node[i] = v.replace("{q}", q).replace("{model}", raw) if isinstance(v, str) else _fill(v, q, raw)
    return node


def get(group: str | None = None, query: str | None = None) -> dict:
    src = load()
    if group and group not in src:
        return err(f"unknown group {group!r}; available: {sorted(src)}")
    data = {group: src[group]} if group else src
    if query:
        data = _fill(json.loads(json.dumps(data)), quote_plus(query), query)
    return {"success": True, "sources_dir": str(sources.BUNDLED), "user_dir": str(root() / ".config"), "sources": data}
