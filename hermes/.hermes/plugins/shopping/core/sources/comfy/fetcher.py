"""comfy.ua — marketplace behind a Cloudflare JS challenge (curl → 403, `browser_exec` → "Just a
moment"). Local headless Chromium (`--headless=new --dump-dom`) passes the challenge by itself in
~3 s and the SSR page embeds `window.__INITIAL_STATE__`:
  catalogsearch.list.items[]   id, sku, name, url (relative .html), category.name, prices.{price,oldPrice},
                               reviews.{rating,count}, remains.flags.isAvailable, creditMonthlyMin,
                               isThirdParty / merchantPublicId (marketplace seller)
  catalogsearch.filter.total   total hits; filter.attributes[code=cat].values[] {description, qty} = categories
"""
from __future__ import annotations

import json
import re
from urllib.parse import quote_plus

from ...http import FetchError, chromium_dom

SITE, GROUP = "comfy", "marketplace"
BASE = "https://comfy.ua"
SEARCH = BASE + "/ua/search/?q={q}"


def _state(page: str) -> dict:
    m = re.search(r"window\.__INITIAL_STATE__\s*=\s*(\{.*)", page, re.S)
    if not m:
        return {}
    try:
        return json.JSONDecoder().raw_decode(m.group(1))[0]
    except ValueError:
        return {}


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    cs = _state(page).get("catalogsearch") or {}
    flt = cs.get("filter") or {}
    if meta is not None:
        meta["total_est"] = flt.get("total") or (cs.get("list") or {}).get("total")
        cat = next((a for a in flt.get("attributes") or [] if a.get("code") == "cat"), {})
        meta["categories"] = [{"name": v.get("description"), "count": v.get("qty")} for v in cat.get("values") or [] if v.get("description")]
    out = []
    for it in (cs.get("list") or {}).get("items") or []:
        if not (it.get("name") and it.get("url")):
            continue
        prices, rev, rem = it.get("prices") or {}, it.get("reviews") or {}, (it.get("remains") or {}).get("flags") or {}
        old = prices.get("oldPrice")
        third = it.get("isThirdParty") or (it.get("merchantPublicId") not in (None, "", "comfy"))
        out.append({
            "group": GROUP, "source": SITE, "title": it["name"], "url": f"{BASE}/ua/{it['url'].lstrip('/')}",
            "price_uah": prices.get("price") or None,
            "price_note": f"было {old} ₴" if old and old != prices.get("price") else "",
            "rating": rev.get("rating") or None, "rating_count": rev.get("count") or None,
            "availability": "в наявності" if rem.get("isAvailable") else "немає",
            "seller": "продавец маркетплейса" if third else "Comfy", "delivery_scope": "ua_local",
            "installment": True if it.get("creditMonthlyMin") else None,
            "installment_note": f"від {it['creditMonthlyMin']} ₴/міс" if it.get("creditMonthlyMin") else "",
            "category": (it.get("category") or {}).get("name") or "",
        })
    return out


REVIEW_URL = BASE + "/ua/review/{slug}"


def parse_reviews(page: str) -> dict:
    rv = _state(page).get("reviews") or {}
    summ = rv.get("reviewsSummary") or {}
    dist = {int(x["productRating"]): x["count"] for x in summ.get("summaryRating") or [] if x.get("productRating")}
    out = []
    for r in rv.get("reviews") or []:
        pr = r.get("productRating")
        out.append({"rating": round(pr / 20) if isinstance(pr, (int, float)) and pr else None,
                    "text": r.get("detail") or "", "pros": r.get("advantages") or "", "cons": r.get("disadvantages") or "",
                    "verified": bool(r.get("wasOrdered"))})
    return {"total": rv.get("reviewsTotal") if rv.get("reviewsTotal") is not None else summ.get("count"),
            "avg": (summ.get("rating") or {}).get("avg"), "distribution": dist or None, "reviews": out}


def reviews(product_url: str) -> dict:
    """Contract for core.reviews. The review tab is its own SSR page: /ua/review/<slug>.html (5 per page)."""
    slug = product_url.rsplit("/", 1)[-1]
    return parse_reviews(chromium_dom(REVIEW_URL.format(slug=slug)))


def search(query: str, meta: dict | None = None) -> list[dict]:
    page = chromium_dom(SEARCH.format(q=quote_plus(query)))
    rows = parse_search(page, meta)
    if not rows and "__INITIAL_STATE__" not in page:
        raise FetchError("comfy: no state in rendered page")
    return rows
