"""epicentrk.ua — marketplace (own stock `epicentrk` + third-party `mplc`). Nuxt SSR; curl passes.
  search: /ua/search/?q=<q> → window.__NUXT__ state.products.products[] (40/page),
          state.pagination.pagination.pages, state.filters.list.categories (facets — useful for probing).
"""
from __future__ import annotations

from urllib.parse import quote_plus

from ...http import FetchError, get, nuxt_state

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


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"epicentr blocked ({r.status})")
    return parse_search(r.text, meta)
