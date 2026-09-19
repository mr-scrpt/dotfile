"""allo.ua — marketplace. Search page server-rendered; curl passes.
  search: /ua/catalogsearch/result/?q=<q> → <div class="product-card"> … product-card__title, v-pb__price-row (old, current)
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

import json

from ...http import FetchError, get, text, to_int

SITE, GROUP = "allo", "marketplace"
BASE = "https://allo.ua"
SEARCH = BASE + "/ua/catalogsearch/result/?q={q}"


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    if meta is not None:
        cats = re.findall(r'href="[^"]*catalogsearch/result/index/cat-\d+/[^"]*"[^>]*>\s*<span>([^<]+)</span>\s*<i class="f-radio__amount">\((\d+)\)</i>', page)
        meta["categories"] = [{"name": text(n), "count": to_int(c)} for n, c in cats]
        meta["total_est"] = max((to_int(c) for _, c in cats), default=None)
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


REVIEWS_XHR = (BASE + "/ua/discussion/reviewQuestion/update/?tab_id=reviews&tab=discussion&product_id={pid}"
               "&isAjax=1&currentLocale=uk_UA&page={page}")
NUXT_HEADERS = ("X-USE-NUXT: 1", "X-Requested-With: XMLHttpRequest")


def product_id(card_page: str) -> str | None:
    m = re.search(r"allomobileua://\?product=(\d+)", card_page)
    return m.group(1) if m else None


def parse_reviews(raw: dict) -> dict:
    """reviewQuestion/update JSON → contract dict. items[] {type review|question, text, rating{value},
    was_bought_in_allo}; count_items counts reviews+questions."""
    out = []
    for r in raw.get("items") or []:
        if not isinstance(r, dict) or r.get("type") not in (None, "review"):
            continue
        rating = (r.get("rating") or {}).get("value") if isinstance(r.get("rating"), dict) else r.get("rating")
        out.append({"rating": int(rating) if rating not in (None, "") else None, "text": text(str(r.get("text") or "")),
                    "pros": "", "cons": "", "verified": bool(r.get("was_bought_in_allo"))})
    total = raw.get("count_items") if raw.get("count_items") is not None else len(out)
    return {"total": total, "avg": None, "distribution": None, "reviews": out}


def reviews(product_url: str) -> dict:
    """Contract for core.reviews: card → product id → reviews XHR (2 requests; allo rate-limits bursts)."""
    r = get(product_url)
    if r.blocked:
        raise FetchError(f"allo blocked ({r.status})")
    pid = product_id(r.text)
    if not pid:
        raise FetchError("allo: product id not found on card")
    r2 = get(REVIEWS_XHR.format(pid=pid, page=1), accept="application/json, text/plain, */*",
             headers=NUXT_HEADERS + (f"Referer: {product_url}?tab=discussion",))
    if r2.blocked:
        raise FetchError(f"allo reviews blocked ({r2.status})")
    try:
        return parse_reviews(json.loads(r2.text))
    except json.JSONDecodeError as e:
        raise FetchError("allo reviews: non-JSON (maintenance page?)") from e


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"allo blocked ({r.status})")
    return parse_search(r.text, meta)
