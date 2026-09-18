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

from ..http import FetchError, get, nuxt_state, to_int

SITE, GROUP = "hotline", "aggregator"
BASE = "https://hotline.ua"


# ------------------------------------------------------------------ spec parsing
def parse_spec(spec: list[str]) -> dict:
    """['дисплей: 26,5"', 'QD-OLED', '2560x1440', '16:9', ' частота оновлення: 240 Гц', …] → numbers."""
    joined = " | ".join(spec)
    out: dict[str, object] = {"diagonal_in": None, "panel": None, "resolution": None, "refresh_hz": None, "brightness_nits": None}
    m = re.search(r'дисплей:\s*([\d,.]+)\s*"', joined)
    if m:
        out["diagonal_in"] = float(m.group(1).replace(",", "."))
    m = re.search(r"(\d{3,4}x\d{3,4})", joined)
    if m:
        out["resolution"] = m.group(1)
    for s in spec:
        s = s.strip()
        if re.fullmatch(r"[A-Za-z][A-Za-z \-\(\),0-9\.]*", s) and not re.fullmatch(r"\d+:\d+", s) and "x" not in s.lower()[:1]:
            if any(k in s.upper() for k in ("OLED", "IPS", "VA", "TN", "LED", "PLS")):
                out["panel"] = s
                break
    m = re.search(r"частота оновлення:\s*(\d{2,3})", joined)
    if m:
        out["refresh_hz"] = int(m.group(1))
    m = re.search(r"яскравість:\s*(\d{2,4})", joined)
    if m:
        out["brightness_nits"] = int(m.group(1))
    return out


def _card(p: dict) -> dict:
    spec = parse_spec(p.get("techShortSpecifications") or [])
    vendor = (p.get("vendor") or {}).get("title") or ""
    title = f"{vendor} {p['title']}".strip()
    return {
        "group": GROUP, "source": SITE, "title": title, "model": title,
        "url": BASE + "/ua" + p["url"], "price_min_uah": p.get("minPrice"), "price_max_uah": p.get("maxPrice"),
        "offers_count": p.get("offerCount"), "rating_count": p.get("reviewsCount") or None,
        "notes": "; ".join(s.strip() for s in (p.get("techShortSpecifications") or [])),
        "spec": spec, "date": p.get("date"),
    }


def parse_catalog(page: str) -> dict:
    """Category/search page → {'cards': [...], 'filters': {title: {value: id}}, 'selected': [...], 'pages': N}."""
    st = nuxt_state(page)["state"]
    cat = st.get("catalog") or {}
    prods = cat.get("products") or {}
    if not prods.get("collection"):  # /ua/sr/ search page keeps hits under state.sr.productsSearch
        sr = st.get("sr") or {}
        prods = {"collection": sr.get("productsSearch") or [], "paginationInfo": sr.get("paginationInfo") or {}}
    filters = {}
    for f in cat.get("filters") or []:
        vals = f.get("values") or []
        if f.get("type") in ("simple", "smart", "multiple_values", "vendor", "model_year") and vals:
            filters[f["title"]] = {v["title"]: v["_id"] for v in vals}
    pag = prods.get("paginationInfo") or {}
    return {"cards": [_card(p) for p in prods.get("collection") or []],
            "filters": filters, "selected": [s.get("name") for s in cat.get("filtersSelected") or []],
            "pages": pag.get("lastPage") or 1, "total": pag.get("totalCount")}


def parse_search(page: str) -> list[dict]:
    return parse_catalog(page)["cards"]


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
    del meta  # no site-reported total on this page
    return parse_search(_page(f"{BASE}/ua/sr/?q={quote_plus(query)}"))


def catalog(section: str, filter_ids: list[int], max_pages: int = 6) -> dict:
    """Walk a filtered category: section like 'computer/monitory'."""
    path = "-".join(str(i) for i in filter_ids)
    base = f"{BASE}/ua/{section.strip('/')}/{path}/?sort=1" if path else f"{BASE}/ua/{section.strip('/')}/?sort=1"
    first = parse_catalog(_page(base))
    cards = list(first["cards"])
    for p in range(2, min(first["pages"], max_pages) + 1):
        cards += parse_catalog(_page(f"{base}&p={p}"))["cards"]
    first["cards"] = cards
    return first


def filters(section: str) -> dict:
    """{filter title: {value title: id}} for a section — for sources.yaml maintenance."""
    return parse_catalog(_page(f"{BASE}/ua/{section.strip('/')}/"))["filters"]


def offers(product_url: str) -> dict:
    url = product_url if product_url.startswith("http") else BASE + product_url
    return parse_offers(_page(url.split("?")[0] + "?tab=prices"))


def reviews(product_url: str) -> list[dict]:
    url = product_url if product_url.startswith("http") else BASE + product_url
    return parse_reviews(_page(url.split("?")[0] + "?tab=reviews"))
