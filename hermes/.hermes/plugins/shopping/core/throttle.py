"""Layer 1 — throttle: be a polite client. Per-HOST pacing, response cache, block cooldown.

Mechanism, not policy: nothing here knows any site. Every source folder may declare its own
politeness in `source.yaml`:

    rate:
      min_delay: 3.0     # seconds between two requests to this host (default DEFAULTS)
      jitter: 1.5        # random extra 0..jitter, so the pattern is not machine-regular
      cache_ttl: 900     # seconds an identical URL is served from disk instead of the network
      cooldown: 900      # seconds to stay away after the host answered with a block/captcha

Requests to one host are serialised (a per-host lock) while different hosts still run in
parallel, so the parallel probe stays fast without hammering anyone. After a blocked answer the
host is put on cooldown and further requests fail fast with a clear message instead of digging
the hole deeper.
"""
from __future__ import annotations

import hashlib
import json
import random
import threading
import time
from pathlib import Path
from urllib.parse import urlsplit

from .fs import root

DEFAULTS = {"min_delay": 2.0, "jitter": 1.0, "cache_ttl": 600.0, "cooldown": 900.0}

_locks: dict[str, threading.Lock] = {}
_last_hit: dict[str, float] = {}
_cooling: dict[str, tuple[float, str]] = {}      # host → (until_ts, reason)
_guard = threading.Lock()
_rates: dict[str, dict] = {}                      # host → rate settings (filled by register_rate)


class Cooling(RuntimeError):
    """The host answered with a block/captcha recently; stay away until it expires."""


def host_of(url: str) -> str:
    return (urlsplit(url).hostname or "").lower().removeprefix("www.")


def register_rate(url_or_host: str, rate: dict | None) -> None:
    """Declare a host's politeness (called by the source registry from source.yaml)."""
    host = host_of(url_or_host) or url_or_host
    if host:
        _rates[host] = {**DEFAULTS, **(rate or {})}


def rate_for(host: str) -> dict:
    return _rates.get(host, DEFAULTS)


def _cache_dir() -> Path:
    d = root() / ".cache" / "http"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _cache_path(url: str) -> Path:
    return _cache_dir() / (hashlib.sha256(url.encode()).hexdigest()[:32] + ".json")


def cached(url: str, ttl: float | None = None) -> dict | None:
    """Fresh cached response for this exact URL, or None."""
    ttl = rate_for(host_of(url))["cache_ttl"] if ttl is None else ttl
    if ttl <= 0:
        return None
    p = _cache_path(url)
    try:
        if p.is_file() and time.time() - p.stat().st_mtime < ttl:
            return json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return None


def store(url: str, status: int, text: str, final_url: str) -> None:
    if rate_for(host_of(url))["cache_ttl"] <= 0:
        return
    try:
        _cache_path(url).write_text(json.dumps({"status": status, "text": text, "url": final_url}),
                                    encoding="utf-8")
    except OSError:
        pass


def cooldown_left(host: str) -> float:
    with _guard:
        until, _ = _cooling.get(host, (0.0, ""))
    return max(0.0, until - time.time())


def mark_blocked(url: str, reason: str = "blocked") -> None:
    """Remember that this host refused us, so the next calls fail fast instead of hammering."""
    host = host_of(url)
    with _guard:
        _cooling[host] = (time.time() + rate_for(host)["cooldown"], reason)


def clear(host: str) -> None:
    with _guard:
        _cooling.pop(host, None)


def wait_turn(url: str) -> None:
    """Block until it is polite to hit this host again; raise Cooling while it is on cooldown."""
    host = host_of(url)
    left = cooldown_left(host)
    if left > 0:
        with _guard:
            reason = _cooling.get(host, (0, ""))[1]
        raise Cooling(f"{host}: {reason}; повтор через {int(left)} c")
    with _guard:
        lock = _locks.setdefault(host, threading.Lock())
    rate = rate_for(host)
    lock.acquire()
    try:
        gap = time.time() - _last_hit.get(host, 0.0)
        need = rate["min_delay"] + random.uniform(0, rate["jitter"])
        if gap < need:
            time.sleep(need - gap)
        _last_hit[host] = time.time()
    finally:
        lock.release()


def state() -> dict:
    """Diagnostics for the model/CLI: who is cooling down and for how long."""
    with _guard:
        cooling = {h: {"left_s": int(max(0, until - time.time())), "reason": why}
                   for h, (until, why) in _cooling.items() if until > time.time()}
    return {"cooling_down": cooling, "rates": _rates}
