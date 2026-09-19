"""citrus.ua — marketplace. Next.js SSR; curl passes.
  search: /search/?query=<q> (NOT ?q= — that renders an empty list) → __NEXT_DATA__
          props.pageProps.products[] {name, url, prices.price/old, reviews.rating/commentsCount,
          status.type CAN_BUY|…, labels[]}, pageProps.counts.totalCount.
"""
from __future__ import annotations

import json
import re
from urllib.parse import quote_plus

from ...http import FetchError, get

SITE, GROUP = "citrus", "marketplace"
BASE = "https://citrus.ua"
SEARCH = BASE + "/search/?query={q}"


def _next_data(page: str) -> dict:
    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', page, re.S)
    return json.loads(m.group(1)) if m else {}


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    pp = (_next_data(page).get("props") or {}).get("pageProps") or {}
    if meta is not None:
        meta["total_est"] = (pp.get("counts") or {}).get("totalCount")
        cat_attr = next((a for a in pp.get("attributes") or [] if a.get("id") == "categories"), {})
        meta["categories"] = [{"name": i.get("title"), "count": i.get("count")} for i in cat_attr.get("items") or [] if i.get("title")]
    out = []
    for p in pp.get("products") or []:
        if not (p.get("name") and p.get("url")):
            continue
        prices, rev, st = p.get("prices") or {}, p.get("reviews") or {}, p.get("status") or {}
        old = prices.get("old") or 0
        used = p["name"].startswith("Б/В")
        out.append({
            "group": GROUP, "source": SITE, "title": p["name"], "url": BASE + p["url"],
            "price_uah": prices.get("price") or None,
            "price_note": f"было {old} ₴" if old and old != prices.get("price") else "",
            "rating": rev.get("rating") or None, "rating_count": rev.get("commentsCount") or None,
            "availability": (st.get("description") or st.get("type") or "").lower(),
            "seller": "Цитрус", "delivery_scope": "ua_local",
            "notes": "б/у" if used else "",
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"citrus blocked ({r.status})")
    return parse_search(r.text, meta)
