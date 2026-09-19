"""pn.com.ua (Прайс Навигатор) — aggregator. Server-rendered; curl passes.
  search: /search/?fn=<q>&tab=products → "Товари N", model blocks: title link /md/<id>/,
          "N грн за цінами A ... B грн, в K магазинах", rating block, review count.
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ...http import FetchError, get, text, to_int

SITE, GROUP = "pn", "aggregator"
BASE = "https://pn.com.ua"
SEARCH = BASE + "/search/?fn={q}&tab=products"


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    t_all = text(page)
    if meta is not None:
        m = re.search(r"Товари\s*(\d+)", t_all)
        meta["total_est"] = to_int(m.group(1)) if m else None
    out = []
    seen = set()
    for c in re.split(r'<div class="catalog-product-head', page)[1:]:
        c = re.sub(r"<svg.*?</svg>", "", c, flags=re.S)
        url = re.search(r'href="(/md/(\d+)/)"', c)
        if not url or url.group(2) in seen:
            continue
        seen.add(url.group(2))
        t = text(c[:6000])
        title = re.search(r'href="/md/\d+/"[^>]*>(.*?)</a>', c, re.S)
        ttl = text(title.group(1)) if title else ""
        rng = re.search(r"за цінами\s*([\d\s\u00a0]+)\s*\.\.\.\s*([\d\s\u00a0]+)\s*грн,?\s*в\s*(\d+)\s*магазин", t)
        price = re.search(r"([\d\s\u00a0]{4,})\s*грн\s*за цінами", t)
        cnt = re.search(r"(\d+)\s*відгук", t)
        if not ttl:
            continue
        out.append({
            "group": GROUP, "source": SITE, "title": ttl, "url": BASE + url.group(1),
            "price_uah": to_int(price.group(1)) if price else None,
            "price_min_uah": to_int(rng.group(1)) if rng else None,
            "price_max_uah": to_int(rng.group(2)) if rng else None,
            "offers_count": to_int(rng.group(3)) if rng else None,
            "rating_count": to_int(cnt.group(1)) if cnt else None,
            "delivery_scope": "ua_local",
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"pn blocked ({r.status})")
    return parse_search(r.text, meta)
