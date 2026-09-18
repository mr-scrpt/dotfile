"""Layer 1 — HTTP + HTML primitives shared by fetchers. No site knowledge here.

`get()` is the only network call in the plugin: curl with a browser UA (curl is what proved to pass
the UA sites' checks; urllib gets 403 on some). Tests never call it — fetchers accept raw text.
"""
from __future__ import annotations

import html as _html
import json
import re
import subprocess
from dataclasses import dataclass

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36"
_NUM = re.compile(r"[^\d]")


class FetchError(RuntimeError):
    pass


@dataclass
class Response:
    status: int
    text: str
    url: str

    @property
    def blocked(self) -> bool:
        return self.status in (403, 429, 503) or "Just a moment" in self.text[:5000]


def get(url: str, timeout: int = 25, accept: str = "text/html,application/json;q=0.9,*/*;q=0.8") -> Response:
    cmd = ["curl", "-sL", "--max-time", str(timeout), "-A", UA, "-H", f"Accept: {accept}",
           "-H", "Accept-Language: uk-UA,uk;q=0.9,ru;q=0.8", "-w", "\n%{http_code}\n%{url_effective}", url]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, errors="replace", timeout=timeout + 5).stdout
    except (subprocess.TimeoutExpired, OSError) as e:
        raise FetchError(f"curl failed: {e}") from e
    body, _, tail = out.rpartition("\n")
    body, _, code = body.rpartition("\n")
    try:
        return Response(int(code), body, tail.strip())
    except ValueError as e:
        raise FetchError(f"curl gave no status for {url}") from e


def get_json(url: str, timeout: int = 25):
    r = get(url, timeout, accept="application/json, text/plain, */*")
    if r.blocked:
        raise FetchError(f"blocked ({r.status}) {url}")
    try:
        return json.loads(r.text, strict=False)
    except json.JSONDecodeError as e:
        raise FetchError(f"non-JSON from {url}: {r.text[:120]!r}") from e


def text(fragment: str) -> str:
    """Tags → spaces, entities decoded, whitespace collapsed."""
    return re.sub(r"\s+", " ", _html.unescape(re.sub(r"<[^>]+>", " ", fragment))).strip()


def to_int(s) -> int | None:
    """'24 999 ₴' → 24999; '11008.01' → 11008 (decimal part dropped, not glued)."""
    if s is None:
        return None
    if isinstance(s, (int, float)):
        return int(s)
    m = re.search(r"\d[\d\s\u00a0]*", str(s))
    if not m:
        return None
    digits = re.sub(r"\D", "", m.group(0))
    return int(digits) if digits else None


def ld_json(page: str) -> list[dict]:
    out = []
    for m in re.finditer(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', page, re.S):
        try:
            d = json.loads(m.group(1), strict=False)
        except json.JSONDecodeError:
            continue
        out.extend(d if isinstance(d, list) else [d])
    return out


def nuxt_state(page: str) -> dict:
    """Evaluate the `window.__NUXT__=(function(...){...})(...)` payload with node and return it.
    The payload is a self-contained IIFE — node runs it without network or DOM."""
    i = page.find("window.__NUXT__=")
    if i < 0:
        raise FetchError("no __NUXT__ payload in page")
    j = page.find("</script>", i)
    blob = page[i + len("window.__NUXT__="):j].rstrip().rstrip(";")
    script = "const out=" + blob + ";process.stdout.write(JSON.stringify(out));"
    try:  # payload is ~1 MB — feed via stdin, argv would overflow
        out = subprocess.run(["node", "-"], input=script, capture_output=True, text=True, timeout=30, check=True).stdout
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as e:
        raise FetchError(f"node eval of __NUXT__ failed: {getattr(e, 'stderr', '') or e}") from e
    return json.loads(out)
