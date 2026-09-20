"""Layer 1 — source registry: every site is a self-contained package `core/sources/<key>/`.

    <key>/source.yaml   declarative: key, title, group, fetch (script|chromium|browser), search URL, notes,
                        optional filters (structured category ids), optional `order` (int, default 100)
    <key>/fetcher.py    optional: parse_search(page, meta) + search(query, meta) [+ catalog/offers/…]

Adding a site = adding a folder. Nothing else in the plugin lists sites. `fetch: script` without a
fetcher.py is a configuration error surfaced by `validate()` (and the tests). Extra sites may live
under ~/shopping/.config/sources/<key>/ — same layout — and override bundled ones by key.
"""
from __future__ import annotations

import importlib
import importlib.util
import sys
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from types import ModuleType

from ..fs import root

GROUPS = ("aggregator", "marketplace")                  # rendering order: aggregators first
BUNDLED = Path(__file__).resolve().parent


@dataclass(frozen=True)
class Source:
    key: str
    title: str
    group: str
    fetch: str                     # "script" (curl) | "chromium" (headless Chromium, still scripted) | "browser" (agent)
    search: str                    # URL template with {q}
    order: int = 100
    notes: str = ""
    filters: dict = field(default_factory=dict)
    rate: dict = field(default_factory=dict)   # politeness for this host (see core.throttle)
    dir: Path = BUNDLED

    @property
    def scripted(self) -> bool:
        """Has a parser the plugin can run without the agent (curl or local Chromium)."""
        return self.fetch in ("script", "chromium") and (self.dir / "fetcher.py").exists()

    def module(self) -> ModuleType:
        """Import <key>/fetcher.py (cached per process) — only for scripted sources."""
        if not self.scripted:
            raise KeyError(f"no fetcher for {self.key!r}")
        return _load_module(self.key, self.dir / "fetcher.py")

    @property
    def host(self) -> str:
        """Hostname of the search URL, without www — used to map a product URL to its source."""
        from urllib.parse import urlparse
        return (urlparse(self.search).hostname or "").lower().removeprefix("www.")

    def search_url(self, query: str) -> str:
        from urllib.parse import quote_plus
        return self.search.replace("{q}", quote_plus(query))

    def public(self) -> dict:
        return {"key": self.key, "title": self.title, "group": self.group, "fetch": self.fetch,
                "scripted": self.scripted, "search": self.search, "notes": self.notes}


def _load_module(key: str, path: Path) -> ModuleType:
    """Bundled sources are real packages → import_module; user-dir sources load by file path."""
    if path.parent.parent == BUNDLED:
        return importlib.import_module(f"{__name__}.{key}.fetcher")
    name = f"shopping_user_sources.{key}.fetcher"
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def _read(dir_: Path) -> Source | None:
    import yaml
    y = dir_ / "source.yaml"
    if not y.is_file():
        return None
    d = yaml.safe_load(y.read_text(encoding="utf-8")) or {}
    return Source(key=d.get("key") or dir_.name, title=d.get("title") or dir_.name, group=d.get("group", "marketplace"),
                  fetch=d.get("fetch", "browser"), search=d.get("search", ""), order=int(d.get("order", 100)),
                  notes=d.get("notes", "") or "", filters=d.get("filters") or {},
                  rate=d.get("rate") or {}, dir=dir_)


def _scan(base: Path) -> dict[str, Source]:
    out = {}
    if base.is_dir():
        for d in sorted(base.iterdir()):
            if d.is_dir() and not d.name.startswith(("_", ".")):
                s = _read(d)
                if s:
                    out[s.key] = s
    return out


@lru_cache(maxsize=1)
def _registry() -> dict[str, Source]:
    reg = _scan(BUNDLED)
    reg.update(_scan(root() / ".config" / "sources"))     # user additions / overrides
    from ..throttle import register_rate                  # pacing is declared per source package
    for src in reg.values():
        if src.search:
            register_rate(src.search, src.rate)
    return reg


def reload() -> None:
    _registry.cache_clear()


def all_sources() -> list[Source]:
    """Catalogue order: group (aggregator, marketplace) → `order` → key."""
    return sorted(_registry().values(), key=lambda s: (GROUPS.index(s.group) if s.group in GROUPS else 9, s.order, s.key))


def get(key: str) -> Source:
    try:
        return _registry()[key]
    except KeyError:
        raise KeyError(f"unknown source {key!r}; known: {sorted(_registry())}") from None


def scripted() -> list[Source]:
    return [s for s in all_sources() if s.scripted]


def validate() -> list[str]:
    """Configuration problems, empty when healthy."""
    problems = []
    for s in _registry().values():
        if s.group not in GROUPS:
            problems.append(f"{s.key}: group {s.group!r} not in {GROUPS}")
        if s.fetch not in ("script", "chromium", "browser"):
            problems.append(f"{s.key}: fetch {s.fetch!r} must be script|chromium|browser")
        if s.fetch in ("script", "chromium") and not (s.dir / "fetcher.py").exists():
            problems.append(f"{s.key}: fetch: {s.fetch} but no fetcher.py")
        if "{q}" not in s.search:
            problems.append(f"{s.key}: search URL has no {{q}}")
        if s.scripted:
            m = s.module()
            for fn in ("search", "parse_search"):
                if not callable(getattr(m, fn, None)):
                    problems.append(f"{s.key}: fetcher.py lacks {fn}()")
    return problems
