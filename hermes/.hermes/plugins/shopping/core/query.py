"""Layer 1 — query: make a free-text query survive AND-style site search engines.

Site search is AND-ish: every extra word narrows the result set, and a brief like
"монітор 27 OLED 2K 100 Гц" returns ZERO on most sites because no title contains all of it.
The fix is mechanical and category-agnostic: drop the least useful trailing word and retry,
until the source answers. Nothing here knows any product, brand or language — it only counts
words and asks the caller (a closure) how many hits a variant produced.
"""
from __future__ import annotations

import re

MIN_WORDS = 1
MAX_ATTEMPTS = 4
# A token that is only digits/units ("100", "2K", "Гц") is the first to go: site titles rarely
# carry spec numbers, while the product noun and its brand usually do.
_NOISY = re.compile(r"^[\d]+[\wа-яіїєґ]{0,3}$|^[a-zа-яіїєґ]{1,3}$", re.I)


def variants(query: str, max_attempts: int = MAX_ATTEMPTS) -> list[str]:
    """Progressively shorter versions of `query`, most specific first.

    "монітор 27 OLED 2K 100 Гц" →
        "монітор 27 OLED 2K 100 Гц", "монітор 27 OLED 2K", "монітор 27 OLED", "монітор 27"
    Noisy spec-ish tokens are dropped before meaningful words, and the order of the remaining
    words is preserved so the query still reads naturally.
    """
    words = (query or "").split()
    out = [" ".join(words)] if words else []
    while len(words) > MIN_WORDS and len(out) < max_attempts:
        drop = next((i for i in range(len(words) - 1, -1, -1) if _NOISY.match(words[i])), len(words) - 1)
        words = words[:drop] + words[drop + 1:]
        candidate = " ".join(words)
        if candidate and candidate not in out:
            out.append(candidate)
    return out


def widen(query: str, run, min_hits: int = 1, max_attempts: int = MAX_ATTEMPTS):
    """Call `run(variant)` on ever-shorter queries until it returns ≥ min_hits results.

    `run` returns a list (or anything with len()); the first variant that clears `min_hits` wins.
    Returns (result, used_query, tried_queries) — `result` is the last attempt's output even when
    nothing cleared the bar, so the caller can report an honest zero.
    """
    tried: list[str] = []
    result = []
    used = query
    for variant in variants(query, max_attempts):
        tried.append(variant)
        used = variant
        result = run(variant)
        if result is not None and len(result) >= min_hits:
            break
    return result, used, tried
