"""brain.com.ua — computer shop. Server-rendered; curl passes.
  search: /ukr/search/?Search=<q> → cards <div class="br-pp br-pp-ex goods-block__item …"
          data-pid/data-price/data-without-discount-price/data-brand/data-category-name-ua,
          "Знайдено N товарів". Search is loose (accessories flood in) — match by model code.
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ...http import FetchError, get, text, to_int

SITE, GROUP = "brain", "shop"
BASE = "https://brain.com.ua"
SEARCH = BASE + "/ukr/search/?Search={q}"


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    if meta is not None:
        m = re.search(r"Знайдено\s*([\d\s\u00a0]+)\s*товар", text(page))
        meta["total_est"] = to_int(m.group(1)) if m else None
    out = []
    for c in re.split(r'<div class="br-pp br-pp-ex goods-block__item', page)[1:]:
        c = re.sub(r"<svg.*?</svg>", "", c, flags=re.S)
        attrs = dict(re.findall(r'data-(pid|brand|category-name-ua|articul)="([^"]*)"', c[:3000]))
        url = re.search(r'href="(https://brain\.com\.ua/ukr/[^"]+-p\d+\.html)"', c)
        title = re.search(r'br-pp-desc[^>]*>\s*<a href="[^"]+">(.*?)</a>', c, re.S)
        if not (url and attrs.get("pid") and title):
            continue
        ttl = text(title.group(1))
        spec = re.search(r'class="br-pp-i br-pp-i-[a-z]+"[^>]*>(.*?)</div>', c, re.S)
        pm = re.search(r'br-pp-price[^>]*>\s*<span>([\d\s\u00a0]+)</span>', c)
        om = re.search(r'br-pp-op[^>]*>\s*<span>([\d\s\u00a0]+)</span>', c)
        price, old = (to_int(pm.group(1)) if pm else None), (to_int(om.group(1)) if om else None)
        stars = len(re.findall(r'star-g\.svg', c[c.find("br-pp-r"):][:1500])) if "br-pp-r" in c else 0
        out.append({
            "group": GROUP, "source": SITE, "title": ttl, "url": url.group(1),
            "price_uah": price or None, "price_note": f"было {old} ₴" if old and price and old > price else "",
            "rating": float(stars) if stars else None,
            "availability": "в наявності" if "Купити" in text(c) else "",
            "seller": "Brain", "delivery_scope": "ua_local",
            "notes": "; ".join(x for x in (attrs.get("category-name-ua", ""), text(spec.group(1))[:160] if spec else "") if x),
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"brain blocked ({r.status})")
    return parse_search(r.text, meta)
