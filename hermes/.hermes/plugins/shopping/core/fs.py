"""Layer 0 — filesystem primitives. No domain knowledge: paths, atomic JSON/JSONL io, time, slugs."""
from __future__ import annotations

import json
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Iterable


def root() -> Path:
    """State root: $SHOPPING_HOME or ~/shopping. Tests override via the env var."""
    return Path(os.environ.get("SHOPPING_HOME") or Path.home() / "shopping").expanduser()


def config_dir() -> Path:
    """~/shopping/.config — user overrides that must survive a plugin update."""
    return root() / ".config"


def now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def read_json(p: Path, default=None):
    if not p.exists():
        return default
    return json.loads(p.read_text(encoding="utf-8"))


def write_json(p: Path, data) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(p)


def read_jsonl(p: Path) -> list[dict]:
    if not p.exists():
        return []
    return [json.loads(line) for line in p.read_text(encoding="utf-8").splitlines() if line.strip()]


def write_jsonl(p: Path, rows: Iterable[dict]) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    tmp.replace(p)


def append_jsonl(p: Path, row: dict) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


_CYR = str.maketrans("абвгдеёжзийклмнопрстуфхцчшщъыьэюяіїєґ", "abvgdeejzijklmnoprstufhccss_y_euaiieg")


def slugify(text: str, limit: int = 40) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower().strip().translate(_CYR)).strip("-")
    return s[:limit] or "item"


def err(msg: str, **extra) -> dict:
    return {"success": False, "error": msg, **extra}
