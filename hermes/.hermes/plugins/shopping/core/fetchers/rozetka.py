"""rozetka.com.ua — marketplace. Cloudflare blocks headless browsers but plain curl passes.

  search:   search.rozetka.com.ua/ua/search/api/v6/?front-end=true&text=<q>&lang=ua   → data.goods[].id
  details:  xl-catalog-api.rozetka.com.ua/v4/goods/getDetails?front-end=true&product_ids=a,b&lang=ua
            → rating (comments_mark) + count (comments_amount)
  comments: product-api.rozetka.com.ua/v4/comments/get?front-end=true&goods=<id>&page=N&sort=date&limit=30&lang=ua&type=comment
            → data.record.href/fulltitle, data.comments[] (mark, text, dignity, shortcomings, seller_id)
  card:     <href> HTML (ua locale) → ld+json Product offer (price, availability), installment lines,
            "Ціна при оплаті Карткою Rozetka", seller text per review.
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ..http import FetchError, get, get_json, ld_json, text, to_int

SITE, GROUP = "rozetka", "marketplace"
SEARCH = "https://search.rozetka.com.ua/ua/search/api/v6/?front-end=true&text={q}&lang=ua"
DETAILS = "https://xl-catalog-api.rozetka.com.ua/v4/goods/getDetails?front-end=true&product_ids={ids}&lang=ua"
COMMENTS = ("https://product-api.rozetka.com.ua/v4/comments/get?front-end=true&goods={id}&page={page}"
            "&sort=date&limit=30&lang=ua&type=comment")
EU_MARKERS = ("Rozetka EU", "Доставка з Європи", "з ЄС", "з-за кордону")


# ------------------------------------------------------------------ pure parsers
def parse_search(raw: dict) -> list[int]:
    return [g["id"] for g in (raw.get("data") or {}).get("goods") or [] if g.get("id")]


def parse_details(raw: dict) -> dict[int, dict]:
    return {d["id"]: {"rating": d.get("comments_mark"), "rating_count": d.get("comments_amount")}
            for d in raw.get("data") or []}


def parse_comments(raw: dict) -> dict:
    d = raw.get("data") or {}
    rec = d.get("record") or {}
    comments = []
    for c in d.get("comments") or []:
        comments.append({"mark": c.get("mark"), "text": text(c.get("text") or ""), "pros": c.get("dignity") or "",
                         "cons": c.get("shortcomings") or "", "from_buyer": bool(c.get("from_buyer")),
                         "created": (c.get("created") or {}).get("date") if isinstance(c.get("created"), dict) else c.get("created")})
    tc = d.get("total_comments")
    total = tc.get("comment_count_comments") if isinstance(tc, dict) else tc
    return {"id": rec.get("id"), "url": rec.get("href"), "title": rec.get("fulltitle"),
            "total_comments": total, "pages": (d.get("pages") or {}).get("count") if isinstance(d.get("pages"), dict) else d.get("pages"),
            "comments": comments}


def parse_card(page: str) -> dict:
    """Card HTML → price, availability, installment, seller, EU flag."""
    out = {"price_uah": None, "availability": "", "installment": None, "installment_note": "",
           "seller": "", "delivery_scope": "ua_local", "price_note": ""}
    for d in ld_json(page):
        if d.get("@type") == "Product":
            off = d.get("offers") or {}
            out["price_uah"] = to_int(off.get("price"))
            av = off.get("availability") or ""
            out["availability"] = "в наявності" if av.endswith("InStock") else ("немає" if av.endswith("OutOfStock") else av.rsplit("/", 1)[-1])
            out["title"] = d.get("name")
            break
    t = text(page)
    m = re.search(r"([\d\s\u00a0]{4,})₴\s*Ціна при оплаті Карткою Rozetka", t)
    if m:
        out["price_note"] = f"{to_int(m.group(1))} ₴ картою Rozetka"
    lines = re.findall(r"(Rozetka|ПриватБанк|Monobank|monobank|А-Банк|ПУМБ|Sense)\s+від\s+([\d\s\u00a0]+)₴\s+x\s*(\d+)", t)
    if lines:
        out["installment"] = True
        out["installment_note"] = "; ".join(f"{b} x{n} від {to_int(p)} ₴" for b, p, n in lines)
    elif "Оплатити частинами" in t:
        out["installment"] = True
    sellers = re.findall(r"Продавець:\s*([^\s].{0,40}?)(?=\s{1,}[А-ЯA-Z]|\s{2,}|$)", t)
    if sellers:
        out["seller"] = max(set(sellers), key=sellers.count).strip(" .")
    if any(mk in t for mk in EU_MARKERS) or "Rozetka EU" in (out.get("seller") or ""):
        out["delivery_scope"] = "ua_delivery"
    return out


def seller_from_url(url: str) -> str:
    """Rozetka's own listings have a slug URL (/msi-mag-274qp-…/p581847193/); third-party marketplace
    listings get a numeric-only slug (/520016654/p520016654/). Seller names of third parties are
    rendered client-side only, so the URL shape is the deterministic signal."""
    m = re.search(r"rozetka\.com\.ua/(?:ua/)?([^/]+)/p(\d+)/?", url or "")
    if not m:
        return ""
    return "продавец маркетплейса" if m.group(1).isdigit() else "Rozetka"


# ------------------------------------------------------------------ network
def search(query: str, limit: int = 5, with_card: bool = True, comments_pages: int = 1) -> list[dict]:
    """Findings for the top `limit` search hits. Each: offer fields + `reviews` (list) for the caller."""
    ids = parse_search(get_json(SEARCH.format(q=quote_plus(query))))[:limit]
    if not ids:
        return []
    details = parse_details(get_json(DETAILS.format(ids=",".join(map(str, ids)))))
    out = []
    for gid in ids:
        cm = parse_comments(get_json(COMMENTS.format(id=gid, page=1)))
        for p in range(2, min(cm.get("pages") or 1, comments_pages) + 1):
            cm["comments"] += parse_comments(get_json(COMMENTS.format(id=gid, page=p)))["comments"]
        f = {"group": GROUP, "source": SITE, "title": cm.get("title") or "", "url": cm.get("url") or "",
             "rating": details.get(gid, {}).get("rating") or None, "rating_count": details.get(gid, {}).get("rating_count") or None,
             "seller": seller_from_url(cm.get("url") or ""), "reviews": cm["comments"]}
        if with_card and f["url"]:
            r = get(f["url"].replace("rozetka.com.ua/", "rozetka.com.ua/ua/") if "/ua/" not in f["url"] else f["url"])
            if r.blocked:
                f["notes"] = f"card blocked ({r.status}); price unavailable"
            else:
                card = parse_card(r.text)
                if not card.get("seller"):
                    card.pop("seller", None)
                f.update({k: v for k, v in card.items() if v not in (None, "", [])})
        out.append(f)
    return out
