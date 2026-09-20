"""Layer 1 — HTTP + HTML primitives shared by fetchers. No site knowledge here.

Two network primitives, both subprocess-based so the plugin has no Python deps:
  get()           curl with a browser UA (passes most UA sites; urllib gets 403 on some).
  chromium_dom()  real headless Chromium `--dump-dom` for Cloudflare-challenged sites (comfy): the
                  challenge is solved by the browser itself in ~3 s; a persistent profile keeps the
                  clearance cookie so later hits are cheaper. No CDP/browser_exec — one process per
                  page, nothing enters the model context.
Tests never call either — fetchers accept raw text.
"""
from __future__ import annotations

import html as _html
import json
import re
import subprocess
from dataclasses import dataclass

from . import throttle
from .throttle import Cooling  # noqa: F401  (re-exported: callers catch it next to FetchError)

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36"
_NUM = re.compile(r"[^\d]")


class FetchError(RuntimeError):
    pass


@dataclass
class Response:
    status: int
    text: str
    url: str

    BLOCK_MARKERS = ("just a moment", "не робот", "не робот", "recaptcha", "g-recaptcha",
                     "captcha", "проверка браузера", "перевірка браузера", "access denied")

    @property
    def blocked(self) -> bool:
        """HTTP refusal, or a 200 page that is really a challenge (captcha/interstitial).
        A block is a signal to back off, never to retry harder."""
        if self.status in (401, 403, 429, 503):
            return True
        head = self.text[:8000].casefold()
        return any(m in head for m in self.BLOCK_MARKERS)


def get(url: str, timeout: int = 25, accept: str = "text/html,application/json;q=0.9,*/*;q=0.8",
        headers: tuple[str, ...] = (), cache: bool = True) -> Response:
    """Polite GET: serves a fresh cached copy when there is one, otherwise waits for this host's
    turn (see core.throttle), and puts the host on cooldown when the answer is a block."""
    if cache:
        hit = throttle.cached(url)
        if hit:
            return Response(hit["status"], hit["text"], hit["url"])
    throttle.wait_turn(url)                    # raises Cooling while the host is off-limits
    cmd = ["curl", "-sL", "--compressed", "--max-time", str(timeout), "-A", UA, "-H", f"Accept: {accept}",
           "-H", "Accept-Language: uk-UA,uk;q=0.9,ru;q=0.8",
           "-H", "Accept-Encoding: gzip, deflate, br", "-H", "Connection: keep-alive",
           "-H", "Sec-Fetch-Dest: document", "-H", "Sec-Fetch-Mode: navigate", "-H", "Sec-Fetch-Site: same-origin",
           "-H", "Upgrade-Insecure-Requests: 1",
           "--cookie-jar", str(_cookie_jar(url)), "--cookie", str(_cookie_jar(url))]
    for h in headers:
        cmd += ["-H", h]
    cmd += ["-w", "\n%{http_code}\n%{url_effective}", url]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, errors="replace", timeout=timeout + 5).stdout
    except (subprocess.TimeoutExpired, OSError) as e:
        raise FetchError(f"curl failed: {e}") from e
    body, _, tail = out.rpartition("\n")
    body, _, code = body.rpartition("\n")
    try:
        resp = Response(int(code), body, tail.strip())
    except ValueError as e:
        raise FetchError(f"curl gave no status for {url}") from e
    if resp.blocked:
        throttle.mark_blocked(url, f"ответ {resp.status} похож на блок/капчу")
    elif cache:
        throttle.store(url, resp.status, resp.text, resp.url)
    return resp


def _cookie_jar(url: str):
    """One cookie jar per host: a session cookie makes the client look like a returning browser."""
    from .fs import root
    d = root() / ".cache" / "cookies"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{throttle.host_of(url) or 'default'}.txt"


CHROMIUM_BIN = ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable", "chrome")
CHROMIUM_UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"


def chromium_path() -> str | None:
    import shutil
    return next((p for b in CHROMIUM_BIN if (p := shutil.which(b))), None)


def chromium_dom(url: str, timeout: int = 40, budget_ms: int = 4000, profile: str | None = None) -> str:
    """Rendered DOM of `url` via headless Chromium. Raises FetchError when Chromium is missing, times
    out, or the page is still a Cloudflare challenge."""
    from pathlib import Path
    binary = chromium_path()
    if not binary:
        raise FetchError("chromium not installed (needed for fetch: chromium sites)")
    prof = profile or str(Path.home() / ".cache" / "shopping-chromium")
    cmd = [binary, "--headless=new", "--no-sandbox", "--disable-gpu", "--no-first-run", "--disable-extensions",
           f"--user-data-dir={prof}", "--window-size=1366,768", f"--user-agent={CHROMIUM_UA}",
           f"--virtual-time-budget={budget_ms}", "--dump-dom", url]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, errors="replace", timeout=timeout).stdout
    except subprocess.TimeoutExpired as e:
        raise FetchError(f"chromium timed out on {url}") from e
    except OSError as e:
        raise FetchError(f"chromium failed: {e}") from e
    if not out.strip():
        raise FetchError(f"chromium returned empty DOM for {url}")
    if "Just a moment" in out[:5000] or "challenge-platform" in out[:20000]:
        raise FetchError(f"cloudflare challenge not passed for {url}")
    return out


def get_json(url: str, timeout: int = 25, headers: tuple[str, ...] = ()):
    r = get(url, timeout, accept="application/json, text/plain, */*", headers=headers)
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
