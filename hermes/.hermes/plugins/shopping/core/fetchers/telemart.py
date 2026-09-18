"""telemart.ua — computer shop. Search page server-rendered; curl passes.
  search: /ua/search/<q>/ → <div class="product-item col-lg-3 …"> with data-prod-* attributes,
          product-item-cost-column (old / current / "Від N ₴ / міс."), product-item--not-available.
"""
from __future__ import annotations

import re
from urllib.parse import quote

from ..http import FetchError, get, text, to_int

SITE, GROUP = "telemart", "shop"
BASE = "https://telemart.ua"
SEARCH = BASE + "/ua/search/{q}/"


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    out = []
    for c in re.split(r'<div class="product-item col-lg-3', page)[1:]:
        c = re.sub(r"<svg.*?</svg>", "", c, flags=re.S)
        attrs = dict(re.findall(r'data-(prod-name|prod-brand|prod-price|id_product)="([^"]*)"', c[:4000]))
        url = re.search(r'href="(https://telemart\.ua/ua/products/[^"]+)"', c)
        title = re.search(r'product-item__title[^>]*>(.*?)</(?:a|div)>', c, re.S)
        if not (url and (title or attrs.get("prod-name"))):
            continue
        cost = text(c[c.find("product-item-cost-column"):][:700])
        prices = [p for p in (to_int(x) for x in re.findall(r"([\d\s\u00a0]{4,})\s*₴", cost)) if p]
        monthly = re.search(r"[Вв]ід\s*([\d\s\u00a0]+)\s*₴\s*/\s*міс", cost)
        na = "product-item--not-available" in c[:600] or "Немає в наявності" in cost
        cnt = re.search(r"(\d+)\s*відгук", text(c[c.find("product-item__comments"):][:300]))
        out.append({
            "group": GROUP, "source": SITE, "title": text(title.group(1)) if title else attrs["prod-name"],
            "url": url.group(1),
            "price_uah": to_int(attrs.get("prod-price")) or (prices[-1] if prices else None),
            "price_note": f"было {prices[0]} ₴" if len(prices) >= 2 and prices[0] != prices[-1] else "",
            "rating_count": to_int(cnt.group(1)) if cnt else None,
            "availability": "немає в наявності" if na else "в наявності",
            "seller": "Telemart", "delivery_scope": "ua_local",
            "installment": True if monthly else None,
            "installment_note": f"від {to_int(monthly.group(1))} ₴/міс" if monthly else "",
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote(query)))
    if r.blocked:
        raise FetchError(f"telemart blocked ({r.status})")
    return parse_search(r.text, meta)
