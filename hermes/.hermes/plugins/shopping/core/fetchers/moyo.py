"""moyo.ua — marketplace. Search page server-rendered; curl passes.
  search: /ua/search/new/?q=<q> → <div class="product-card  goods-item …" data-price=… data-status-product=…>
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ..http import FetchError, get, text, to_int

SITE, GROUP = "moyo", "marketplace"
BASE = "https://www.moyo.ua"
SEARCH = BASE + "/ua/search/new/?q={q}"


def parse_search(page: str) -> list[dict]:
    out = []
    for c in re.split(r'<div class="product-card\s+goods-item', page)[1:]:
        c = re.sub(r"<svg.*?</svg>", "", c, flags=re.S)
        attrs = dict(re.findall(r'data-(product_id|price|brand|status-product)="([^"]*)"', c[:2500]))
        url = re.search(r'href="(https://www\.moyo\.ua/ua/[^"]+\.html)"', c)
        title = re.search(r'product-card_title[^>]*>(.*?)</a>', c, re.S)
        if not (url and title):
            continue
        ttl = text(re.sub(r'<div class="product-card_title_tooltip.*?</div>', "", title.group(1), flags=re.S))
        half = len(ttl) // 2  # tooltip copy may still be present as "X X"
        if len(ttl) % 2 == 1 and ttl[:half] == ttl[half + 1:]:
            ttl = ttl[:half]
        stars = len(re.findall(r'rate-star active-start', c[:c.find("product-card_price") if "product-card_price" in c else len(c)]))
        cnt = re.search(r'product-card_reviews.*?\((\d+)\)', c, re.S)
        old = re.search(r'product-card_price_old[^>]*>\s*([\d\s\u00a0]+)', c)
        t = text(c)
        banks = sorted(set(re.findall(r"(Monobank|ПриватБанк|А-Банк|Sense Bank|ПУМБ|Ощадбанк)", t)))
        out.append({
            "group": GROUP, "source": SITE, "title": ttl, "url": url.group(1),
            "price_uah": to_int(attrs.get("price")), "price_note": f"было {to_int(old.group(1))} ₴" if old else "",
            "rating": float(stars) if stars else None, "rating_count": to_int(cnt.group(1)) if cnt else None,
            "availability": (attrs.get("status-product") or "").lower() or "",
            "seller": "MOYO", "delivery_scope": "ua_local",
            "installment": True if (banks or "js-credit-icons-holder" in c) else None, "installment_note": ", ".join(banks),
        })
    return out


def search(query: str) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"moyo blocked ({r.status})")
    return parse_search(r.text)
