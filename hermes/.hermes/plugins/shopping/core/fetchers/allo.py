"""allo.ua — marketplace. Search page server-rendered; curl passes.
  search: /ua/catalogsearch/result/?q=<q> → <div class="product-card"> … product-card__title, v-pb__price-row (old, current)
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ..http import FetchError, get, text, to_int

SITE, GROUP = "allo", "marketplace"
BASE = "https://allo.ua"
SEARCH = BASE + "/ua/catalogsearch/result/?q={q}"


def parse_search(page: str) -> list[dict]:
    out = []
    for c in re.split(r'<div class="product-card"', page)[1:]:
        c = re.sub(r"<svg.*?</svg>", "", c, flags=re.S)
        url = re.search(r'href="(https://allo\.ua/ua/[^"]+\.html)"', c)
        title = re.search(r'product-card__title[^>]*>(.*?)<', c, re.S)
        if not (url and title):
            continue
        prices = [to_int(p) for p in re.findall(r'([\d\s\u00a0]{4,})\s*₴', text(c[c.find("v-pb__price-row"):][:600]))]
        prices = [p for p in prices if p]
        sku = re.search(r'product-sku__value[^>]*>\s*(\d+)', c)
        rating = re.search(r'rating-value[^>]*>\s*([\d.]+)', c) or re.search(r'>\s*([0-5]\.\d)\s*<', c)
        cnt = re.search(r'(\d+)\s*відгук', text(c))
        t = text(c)
        out.append({
            "group": GROUP, "source": SITE, "title": text(title.group(1)), "url": url.group(1),
            "price_uah": min(prices) if prices else None,
            "price_note": f"было {max(prices)} ₴" if len(prices) > 1 and max(prices) != min(prices) else "",
            "rating": float(rating.group(1)) if rating else None, "rating_count": to_int(cnt.group(1)) if cnt else None,
            "availability": "немає" if re.search(r"Немає в наявності|Закінчився", t) else "в наявності",
            "seller": "Алло", "delivery_scope": "ua_local",
            "installment": True if re.search(r"частин|кредит", t, re.I) else None,
            "notes": f"код {sku.group(1)}" if sku else "",
        })
    return out


def search(query: str) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"allo blocked ({r.status})")
    return parse_search(r.text)
