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

from ...http import FetchError, get, get_json, ld_json, text, to_int

SITE, GROUP = "rozetka", "marketplace"
PROBE_KWARGS = {"limit": 3, "comments_pages": 0}   # cheap mode for core.probe
SEARCH = "https://search.rozetka.com.ua/ua/search/api/v6/?front-end=true&text={q}&lang=ua"
DETAILS = "https://xl-catalog-api.rozetka.com.ua/v4/goods/getDetails?front-end=true&product_ids={ids}&lang=ua&with_extra_info=true"
COMMENTS = ("https://product-api.rozetka.com.ua/v4/comments/get?front-end=true&goods={id}&page={page}"
            "&sort=date&limit=30&lang=ua&type=comment")
EU_MARKERS = ("Rozetka EU", "Доставка з Європи", "з ЄС", "з-за кордону")


# ------------------------------------------------------------------ pure parsers
def parse_search(raw: dict, meta: dict | None = None) -> list[int]:
    d = raw.get("data") or {}
    if meta is not None:
        meta["total_est"] = (d.get("quantities") or {}).get("goods_quantity_total_found")
        cats = (d.get("categories") or {}).get("list_categories") if isinstance(d.get("categories"), dict) else None
        meta["categories"] = _leaf_categories(cats or [])
    return [g["id"] for g in d.get("goods") or [] if g.get("id")]


def _leaf_categories(nodes: list, out: list | None = None) -> list:
    out = out if out is not None else []
    for n in nodes:
        if n.get("children"):
            _leaf_categories(n["children"], out)
        elif n.get("title") and n.get("count"):
            out.append({"name": n["title"], "count": n["count"]})
    return out


def parse_details(raw: dict) -> dict[int, dict]:
    """getDetails(+with_extra_info): rating, count, seller name (marketplace sellers included)."""
    out = {}
    for d in raw.get("data") or []:
        row = {"rating": d.get("comments_mark"), "rating_count": d.get("comments_amount")}
        seller = (d.get("seller") or {}).get("title")
        if seller:
            row["seller"] = seller
        out[d["id"]] = row
    return out


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


def _seller(details_row: dict, url: str) -> str:
    """Real seller name from getDetails when present; else the URL-shape heuristic."""
    name = details_row.get("seller")
    if name and name.lower() != "rozetka":
        return f"{name} (маркетплейс)"
    return name or seller_from_url(url)


def reviews(product_url: str, pages: int = 3) -> dict:
    """Contract for core.reviews. Goods id parsed from …/p<ID>/ ; comments API, newest first."""
    m = re.search(r"/p(\d+)/?", product_url or "")
    if not m:
        raise FetchError(f"rozetka: no goods id in {product_url}")
    gid = int(m.group(1))
    first = parse_comments(get_json(COMMENTS.format(id=gid, page=1)))
    comments = list(first["comments"])
    for p in range(2, min(first.get("pages") or 1, pages) + 1):
        comments += parse_comments(get_json(COMMENTS.format(id=gid, page=p)))["comments"]
    return {"total": first.get("total_comments"), "avg": None, "distribution": None,
            "reviews": [{"rating": c.get("mark"), "text": c.get("text") or "", "pros": c.get("pros") or "",
                         "cons": c.get("cons") or "", "verified": bool(c.get("from_buyer"))} for c in comments]}


# ------------------------------------------------------------------ network
def search(query: str, meta: dict | None = None, limit: int = 5, with_card: bool = True,
           comments_pages: int = 1) -> list[dict]:
    """Findings for the top `limit` search hits. Each: offer fields + `reviews` (list) for the caller.
    `comments_pages=0` = probe mode: titles/ratings from the details API only (2 requests total)."""
    ids = parse_search(get_json(SEARCH.format(q=quote_plus(query))), meta)[:limit]
    if not ids:
        return []
    details = parse_details(get_json(DETAILS.format(ids=",".join(map(str, ids)))))
    out = []
    for gid in ids:
        cm = parse_comments(get_json(COMMENTS.format(id=gid, page=1)))
        det = details.get(gid, {})
        if comments_pages == 0:  # probe mode: title/url/rating only, no card, comments dropped
            out.append({"group": GROUP, "source": SITE, "title": cm.get("title") or "", "url": cm.get("url") or "",
                        "rating": det.get("rating") or None, "rating_count": det.get("rating_count") or None,
                        "seller": _seller(det, cm.get("url") or "")})
            continue
        for p in range(2, min(cm.get("pages") or 1, comments_pages) + 1):
            cm["comments"] += parse_comments(get_json(COMMENTS.format(id=gid, page=p)))["comments"]
        f = {"group": GROUP, "source": SITE, "title": cm.get("title") or "", "url": cm.get("url") or "",
             "rating": det.get("rating") or None, "rating_count": det.get("rating_count") or None,
             "seller": _seller(det, cm.get("url") or ""), "reviews": cm["comments"]}
        if with_card and f["url"]:
            r = get(f["url"].replace("rozetka.com.ua/", "rozetka.com.ua/ua/") if "/ua/" not in f["url"] else f["url"])
            if r.blocked:
                f["notes"] = f"card blocked ({r.status}); price unavailable"
            else:
                card = parse_card(r.text)
                card.pop("seller", None)  # getDetails seller is authoritative; card text is unreliable
                f.update({k: v for k, v in card.items() if v not in (None, "", [])})
        out.append(f)
    return out
