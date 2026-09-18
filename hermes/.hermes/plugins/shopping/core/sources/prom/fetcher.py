"""prom.ua — marketplace of small sellers. Search page server-rendered; curl passes.
  search: /ua/search?search_term=<q> → blocks `data-qaid="product_block"` each with a ld+json Product
          (name, url, sku, brand, offers.price/availability) and data-qaid company_name / company_rating
          (seller reliability %, not a product rating) / product_pay_parts_price_value (оплата частями).
  total: "Показано 1 - 29 товарів з 3000+"
"""
from __future__ import annotations

import json
import re
from urllib.parse import quote_plus

from ...http import FetchError, get, text, to_int

SITE, GROUP = "prom", "marketplace"
BASE = "https://prom.ua"
SEARCH = BASE + "/ua/search?search_term={q}"


def _qaid(block: str, name: str) -> str:
    m = re.search(r'data-qaid="%s"[^>]*>(.*?)</(?:span|div|a|p)>' % name, block, re.S)
    return text(m.group(1)) if m else ""


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    if meta is not None:
        m = re.search(r"з\s*([\d\s]+\+?)\s*<", page) or re.search(r"товарів з\s*([\d\s]+\+?)", text(page))
        meta["total_est"] = to_int((m.group(1) if m else "").replace("+", "")) if m else None
    out = []
    for b in re.split(r'data-qaid="product_block"', page)[1:]:
        b = re.sub(r"<svg.*?</svg>", "", b, flags=re.S)
        ld = re.search(r'\{"@context":"https://schema\.org/","@type":"Product".*?\}(?=\s*</script>|\s*<)', b, re.S)
        prod: dict = {}
        if ld:
            try:
                prod = json.loads(ld.group(0))
            except ValueError:
                prod = {}
        title = text(prod.get("name") or "") or _qaid(b, "product_name")
        url = prod.get("url") or (re.search(r'data-qaid="product_link"[^>]*href="([^"]+)"', b) or [None, None])[1]
        if not (title and url):
            continue
        offer = prod.get("offers") or {}
        if isinstance(offer, list):
            offer = offer[0] if offer else {}
        seller = _qaid(b, "company_name")
        rel = re.search(r'company_rating.{0,3000}?(\d{1,3})\s*%', b, re.S)
        parts = _qaid(b, "product_pay_parts_price_value")
        out.append({
            "group": GROUP, "source": SITE, "title": title, "url": url,
            "price_uah": to_int(offer.get("price")) or to_int(_qaid(b, "product_price")),
            "availability": (_qaid(b, "product_presence") or ("in stock" if "InStock" in str(offer.get("availability")) else "")).lower(),
            "seller": seller, "delivery_scope": "ua_local",
            "installment": True if parts else None, "installment_note": f"від {parts} ₴/міс" if parts else "",
            "notes": f"надійність продавця {rel.group(1)}%" if rel else "",
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"prom blocked ({r.status})")
    return parse_search(r.text, meta)
