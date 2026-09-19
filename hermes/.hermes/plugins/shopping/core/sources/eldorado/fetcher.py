"""eldorado.ua — marketplace. Public JSON search API (the site's own SPA calls it).
  search: https://api.eldorado.ua/v1/new_search?q=<q>&limit=20&sort=relevance.asc&offset=0&lang=ua
          → meta.total, data.collection[]._source {title_ua, name (slug), ext_id, price ("0.00" = no
          price yet), price_discount, sell_status (4 = в наявності, 1 = незабаром/під замовлення),
          total_mark, comments_number, credits[]}.
"""
from __future__ import annotations

from urllib.parse import quote_plus

from ...http import get_json, to_int

SITE, GROUP = "eldorado", "marketplace"
BASE = "https://eldorado.ua"
API = "https://api.eldorado.ua/v1/new_search?q={q}&limit=20&sort=relevance.asc&offset=0&lang=ua"
SELL_STATUS = {"4": "в наявності", "1": "незабаром", "2": "під замовлення", "3": "закінчився", "0": "немає"}


def parse_search(raw: dict, meta: dict | None = None) -> list[dict]:
    if meta is not None:
        meta["total_est"] = (raw.get("meta") or {}).get("total")
    out = []
    for it in ((raw.get("data") or {}).get("collection") or []):
        x = it.get("_source") or it
        title, slug, ext = x.get("title_ua") or x.get("title"), x.get("name"), x.get("ext_id")
        if not (title and slug and ext):
            continue
        price = to_int(x.get("price"))
        disc = to_int(x.get("price_discount"))
        out.append({
            "group": GROUP, "source": SITE, "title": title, "url": f"{BASE}/uk/{slug}/p{ext}/",
            "price_uah": (disc or price) or None,
            "price_note": f"было {price} ₴" if disc and price and disc < price else "",
            "rating": x.get("total_mark") or None, "rating_count": x.get("comments_number") or None,
            "availability": SELL_STATUS.get(str(x.get("sell_status")), ""),
            "seller": "Eldorado", "delivery_scope": "ua_local",
            "installment": True if x.get("credits") else None,
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    return parse_search(get_json(API.format(q=quote_plus(query))), meta)
