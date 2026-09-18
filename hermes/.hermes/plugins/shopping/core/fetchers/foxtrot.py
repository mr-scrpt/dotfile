"""foxtrot.com.ua — marketplace. Search page is server-rendered; curl passes.
  search: /uk/search?query=<q>  → <div class="product-card" data-code=… data-title=…> … price--current, product-rate
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ..http import FetchError, get, text, to_int

SITE, GROUP = "foxtrot", "marketplace"
BASE = "https://www.foxtrot.com.ua"
SEARCH = BASE + "/uk/search?query={q}"


def parse_search(page: str) -> list[dict]:
    out = []
    for c in re.split(r'<div class="product-card[ "]', page)[1:]:
        c = re.sub(r"<svg.*?</svg>", "", c, flags=re.S)
        m = re.search(r'<a[^>]*href="([^"]+)"[^>]*>\s*<div class="product-card__title">(.*?)</div>', c, re.S)
        attrs = dict(re.findall(r'data-(id|code|brand|title)="([^"]*)"', c[:800]))
        if not m or not attrs.get("title"):
            continue
        t = text(c)
        rating = re.search(r'product-rate.*?</i>\s*([\d.]+)', c, re.S)
        cnt = re.search(r'product-reviews-text[^>]*>\s*(\d+)', c)
        price = re.search(r'price--current[^>]*>\s*([\d\s\u00a0]+)', c)
        old = re.search(r'price--old[^>]*>\s*([\d\s\u00a0]+)', c)
        banks = sorted(set(re.findall(r"(Sense Bank|Monobank|ПриватБанк|Альфа-Банк|ПУМБ)", t)))
        out.append({
            "group": GROUP, "source": SITE, "title": text(m.group(2)), "url": BASE + m.group(1),
            "price_uah": to_int(price.group(1)) if price else None,
            "price_note": f"было {to_int(old.group(1))} ₴" if old else "",
            "rating": float(rating.group(1)) if rating else None, "rating_count": to_int(cnt.group(1)) if cnt else None,
            "availability": "немає" if "Немає в наявності" in t else "в наявності",
            "seller": "Фокстрот", "delivery_scope": "ua_local",
            "installment": True if banks else None, "installment_note": ", ".join(banks),
            "notes": f"код {attrs.get('code')}" if attrs.get("code") else "",
        })
    return out


def search(query: str) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"foxtrot blocked ({r.status})")
    return parse_search(r.text)
