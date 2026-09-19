"""hotline.ua — aggregator. Every page embeds its full Nuxt state, so curl + node gives structured
data: catalog filters (with IDs), product cards (spec list, min/max price, offers/reviews count),
per-product offers (shop, price, installment banks, delivery region) and user reviews.

URLs
  category:  /ua/<section>/<id1>-<id2>-…/?sort=1&p=N    (filter IDs joined by '-', 48 cards/page)
  search:    /ua/sr/?q=<query>
  product:   /ua/<section-slug>/<slug>/?tab=prices | ?tab=reviews
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ...http import FetchError, get, nuxt_state, to_int

SITE, GROUP = "hotline", "aggregator"
BASE = "https://hotline.ua"


# ------------------------------------------------------------------ spec parsing
def _card(p: dict, cat_titles: dict[str, str] | None = None) -> dict:
    vendor = (p.get("vendor") or {}).get("title") or ""
    title = f"{vendor} {p['title']}".strip()
    sec = str((p.get("section") or {}).get("_id") or "")
    return {
        "group": GROUP, "source": SITE, "title": title, "model": title,
        "url": BASE + "/ua" + p["url"], "price_min_uah": p.get("minPrice"), "price_max_uah": p.get("maxPrice"),
        "offers_count": p.get("offerCount"), "rating_count": p.get("reviewsCount") or None,
        "notes": "; ".join(s.strip() for s in (p.get("techShortSpecifications") or [])),
        "category": (cat_titles or {}).get(sec, ""), "date": p.get("date"),
    }


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    """/ua/sr/ page → cards with `category` (title of the card's section, from sr.sections)."""
    sr = nuxt_state(page).get("state", {}).get("sr") or {}
    cats = [c for s in sr.get("sections") or [] for c in s.get("catalogs") or [] if c.get("catalogTitle")]
    if meta is not None:
        meta["total_est"] = sr.get("countProducts") or None
        meta["categories"] = [{"name": c["catalogTitle"], "count": c.get("total")} for c in cats]
    titles = {str(c.get("id")): c["catalogTitle"] for c in cats}
    return [_card(p, titles) for p in sr.get("productsSearch") or []]


def parse_offers(page: str) -> dict:
    """?tab=prices page → {'offers': [...], 'title': str, 'url': str}."""
    st = nuxt_state(page)["state"]
    pr = st["product"]
    edges = (pr.get("offers") or {}).get("edges") or []
    offers = []
    for e in edges:
        n = e.get("node", e)
        banks = ((n.get("installment") or {}) if isinstance(n.get("installment"), dict) else {}).get("banks") or []
        inst = "; ".join(f"{b['from']} до {b.get('max_period')} мес" for b in banks) if banks else ""
        offers.append({
            "shop": n.get("firmTitle"), "price_uah": n.get("price"), "condition": n.get("condition"),
            "guarantee": f"{n.get('guaranteeTerm')} {n.get('guaranteeTermName')} {n.get('guaranteeType')}".strip(),
            "shop_reviews": f"+{n.get('reviewsPositiveNumber', 0)}/-{n.get('reviewsNegativeNumber', 0)}",
            "shipping": n.get("shipping"), "from": (n.get("delivery") or {}).get("name"),
            "country": (n.get("delivery") or {}).get("countryCodeFirm"),
            "installment": bool(banks), "installment_note": inst,
            "go_url": BASE + n["conversionUrl"] if n.get("conversionUrl") else None,
        })
    offers.sort(key=lambda o: o["price_uah"] or 10**9)
    vendor = (pr.get("vendor") or {}).get("title") or ""
    return {"title": f"{vendor} {pr.get('title')}".strip(), "url": BASE + "/ua" + (pr.get("url") or ""),
            "offers": offers, "total": (pr.get("offers") or {}).get("totalCount")}


def parse_reviews(page: str) -> list[dict]:
    st = nuxt_state(page)["state"]
    coll = ((st.get("productReviews") or {}).get("allReviews") or {}).get("collection") or []
    out = []
    for r in coll:
        out.append({"rating": r.get("rating"), "date": r.get("date") or r.get("createdAt"),
                    "text": r.get("text") or r.get("comment") or "", "pros": r.get("advantages") or r.get("pros") or "",
                    "cons": r.get("disadvantages") or r.get("cons") or ""})
    return out


# ------------------------------------------------------------------ network
def _page(url: str) -> str:
    r = get(url)
    if r.blocked:
        raise FetchError(f"hotline blocked {url} ({r.status})")
    return r.text


def search(query: str, meta: dict | None = None) -> list[dict]:
    return parse_search(_page(f"{BASE}/ua/sr/?q={quote_plus(query)}"), meta)


def search_page(query: str, page: int) -> list[dict]:
    return parse_search(_page(f"{BASE}/ua/sr/?q={quote_plus(query)}&p={page}"))


def offers(product_url: str) -> dict:
    url = product_url if product_url.startswith("http") else BASE + product_url
    return parse_offers(_page(url.split("?")[0] + "?tab=prices"))


def reviews(product_url: str) -> dict:
    """Contract for core.reviews: {"total", "avg", "distribution", "reviews":[{rating,text,pros,cons,verified}]}."""
    url = product_url if product_url.startswith("http") else BASE + product_url
    rows = parse_reviews(_page(url.split("?")[0] + "?tab=reviews"))
    return {"total": len(rows), "avg": None, "distribution": None,
            "reviews": [{"rating": r.get("rating"), "text": r.get("text") or "", "pros": r.get("pros") or "",
                         "cons": r.get("cons") or "", "verified": False} for r in rows]}
