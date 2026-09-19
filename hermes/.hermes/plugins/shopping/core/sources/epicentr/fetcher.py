"""epicentrk.ua — marketplace (own stock `epicentrk` + third-party `mplc`). Nuxt SSR; curl passes.
  search: /ua/search/?q=<q> → window.__NUXT__ state.products.products[] (40/page),
          state.pagination.pagination.pages, state.filters.list.categories (facets — useful for probing).
"""
from __future__ import annotations

from urllib.parse import quote_plus

from ...http import FetchError, get, get_json, nuxt_state

SITE, GROUP = "epicentr", "marketplace"
BASE = "https://epicentrk.ua"
SEARCH = BASE + "/ua/search/?q={q}"
PER_PAGE = 40
_SELLER = {"epicentrk": "Епіцентр", "mplc": "продавец маркетплейса"}


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    st = nuxt_state(page).get("state", {})
    prods = (st.get("products") or {}).get("products") or []
    pages = ((st.get("pagination") or {}).get("pagination") or {}).get("pages")
    if meta is not None:
        meta["pages"] = pages
        meta["total_est"] = pages * PER_PAGE if pages else len(prods)
        cats = ((st.get("filters") or {}).get("list") or {}).get("categories") or []
        meta["categories"] = [{"name": i.get("name"), "count": None} for c in cats[:1] for i in (c.get("items") or [])[:8] if i.get("name")]
    out = []
    for p in prods:
        if not (p.get("name") and p.get("url")):
            continue
        seller = p.get("seller") or ""
        old = p.get("oldPrice") or p.get("price_old")
        out.append({
            "group": GROUP, "source": SITE, "title": p["name"], "url": p["url"],
            "price_uah": p.get("price"), "price_note": f"было {old} ₴" if old and old != p.get("price") else "",
            "rating": p.get("rating") or None, "rating_count": p.get("commentsCount") or None,
            "availability": (p.get("available") or "").lower(),
            "seller": _SELLER.get(seller, seller), "delivery_scope": "ua_local",
            "category": (p.get("sectionsUa") or "").split()[-1] if p.get("sectionsUa") else "",
            "notes": f"розділ: {p['sectionsUa']}" if p.get("sectionsUa") else "",
        })
    return out


REVIEWS_API = ("https://api.epicentrk.ua/api/v1/review/product_card_list?entity_type=product&show_main=1&type=review"
               "&slug={slug}&from={from_}&limit={limit}&product_page_type=comments")


def parse_reviews(raw: dict) -> dict:
    """review/product_card_list → contract dict. main.rating.items = {"1".."5": count}, review.items[]
    {rating "5", message, benefits, disadvantages, purchased}."""
    main = raw.get("main") or {}
    total = main.get("review_count") if main.get("review_count") is not None else (raw.get("review") or {}).get("count")
    # rating.items are PERCENTAGES of `count` (all feedback incl. questions); convert to review counts
    base = main.get("count") or total or 0
    dist = {int(k): round(v * base / 100) for k, v in ((main.get("rating") or {}).get("items") or {}).items() if v}
    out = []
    for r in (raw.get("review") or {}).get("items") or []:
        try:
            rating = int(float(r.get("rating"))) if r.get("rating") not in (None, "") else None
        except ValueError:
            rating = None
        out.append({"rating": rating, "text": r.get("message") or "", "pros": r.get("benefits") or "",
                    "cons": r.get("disadvantages") or "", "verified": bool(r.get("purchased"))})
    return {"total": total, "avg": (main.get("rating") or {}).get("summary"), "distribution": dist or None, "reviews": out}


def reviews(product_url: str, limit: int = 50) -> dict:
    """Contract for core.reviews. Slug = last path segment without .html; one API call, up to `limit`."""
    slug = product_url.rstrip("/").rsplit("/", 1)[-1].removesuffix(".html")
    return parse_reviews(get_json(REVIEWS_API.format(slug=slug, from_=0, limit=limit),
                                  headers=("Origin: https://epicentrk.ua", "Referer: https://epicentrk.ua/")))  # CORS-gated


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"epicentr blocked ({r.status})")
    return parse_search(r.text, meta)
