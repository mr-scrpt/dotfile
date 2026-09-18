"""Layer 1 — source catalogue (sources.yaml): seed from plugin data, load, fill URL templates."""
from __future__ import annotations

import json
import shutil
from pathlib import Path
from urllib.parse import quote_plus

from .fs import err, root

SEED = Path(__file__).resolve().parent.parent / "data" / "sources.yaml"


def path() -> Path:
    return root() / ".config" / "sources.yaml"


def ensure() -> Path:
    """Copy the seed into ~/shopping/.config once; re-copy when the plugin seed is newer (keeps the user
    copy in sync with plugin updates). A user who edits the copy keeps the edits until the next seed bump —
    the previous copy is kept as sources.yaml.bak so nothing is lost."""
    p = path()
    p.parent.mkdir(parents=True, exist_ok=True)
    if not p.exists():
        shutil.copy2(SEED, p)
    elif SEED.stat().st_mtime > p.stat().st_mtime:
        shutil.copy2(p, p.with_suffix(".yaml.bak"))
        shutil.copy2(SEED, p)
    return p


def load() -> dict:
    import yaml  # PyYAML ships with Hermes
    return yaml.safe_load(ensure().read_text(encoding="utf-8")) or {}


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
    return {"success": True, "path": str(path()), "sources": data}
