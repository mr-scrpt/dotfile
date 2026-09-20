"""ek.ua (E-Katalog) — aggregator. Server-rendered; curl passes.

Search path (important): the public `/ua/ek-list.php?search_=…` endpoint answers bursty traffic
with a reCAPTCHA interstitial, while category/listing pages stay open. The site's own search box
does NOT hit ek-list first — it calls the suggest endpoint

    /ua/mtools/mui_qs3.php?input_dom_id_=ek-search&data_=<query>

which returns a tiny HTML table of links: either a product page (/ua/<SLUG>.htm) or a filtered
listing (/ua/list/<section>/<filter>/). We follow the same route — suggest, then read the листинг
(48 cards per page, full spec blocks). ek-list.php is kept only as a last-resort fallback.

  listing card: <article class="model-short-div"> with <a class='model-short-title' href='…'>,
                a description block, "Відгуки N", "Ціни K від A до B грн".
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ...http import FetchError, get, text, to_int

SITE, GROUP = "ekatalog", "aggregator"
BASE = "https://ek.ua"
SUGGEST = BASE + "/ua/mtools/mui_qs3.php?input_dom_id_=ek-search&data_={q}"
SEARCH = BASE + "/ua/ek-list.php?search_={q}&_a=1"          # fallback only (captcha-prone)
MAX_LISTINGS = 2


def _item_page(page: str) -> list[dict]:
    """Exact-match redirect landed on a product page."""
    t = text(page)
    title = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
    idg = re.search(r"ek-item\.php\?idg_=(\d+)", page)
    rng = re.search(r"від\s*([\d\s\u00a0]+)\s*до\s*([\d\s\u00a0]+)\s*грн", t)
    cnt = re.search(r"Відгуки\s*(\d+)", t)
    if not title:
        return []
    name = text(title.group(1))
    return [{"group": GROUP, "source": SITE, "title": name, "model": model_from_title(name),
             "url": f"{BASE}/ua/ek-item.php?idg_={idg.group(1)}" if idg else BASE,
             "price_min_uah": to_int(rng.group(1)) if rng else None, "price_max_uah": to_int(rng.group(2)) if rng else None,
             "rating_count": to_int(cnt.group(1)) if cnt else None, "delivery_scope": "ua_local",
             "notes": "", "availability": ""}]


COLOURS = r"(чорний|білий|сірий|срібляст\w*|синій|червоний|зелений|рожевий|золот\w*|фіолет\w*|blue|black|white|silver|gr[ae]y)"


def model_from_title(title: str) -> str:
    """'Монітор Asus ROG Strix OLED XG27AQDPG 26.5 " чорний' → 'Asus ROG Strix OLED XG27AQDPG'.
    Drops the leading type word, and everything from a size ('26.5 "', '27 ″') or colour on."""
    t = re.sub(r"\s+", " ", title).strip()
    t = re.sub(r"^[А-ЯІЇЄA-Z][а-яіїєa-z]+(?:\s+[а-яіїєa-z]+)?\s+(?=[A-Z0-9])", "", t)       # "Монітор ", "Зарядний пристрій "
    t = re.split(r"\s\d+(?:[.,]\d+)?\s*(?:\"|″|дюйм)", t)[0]
    t = re.split(r"\s" + COLOURS + r"\b", t, flags=re.I)[0]
    return t.strip(" ,")


def parse_suggest(page: str) -> list[dict]:
    """Suggest table → [{"url", "title", "kind": "listing"|"product"}] in the site's own order."""
    out = []
    for href, label in re.findall(r'<a class="qs-link" href="([^"]+)"[^>]*>(.*?)</a>', page, re.S):
        title = text(re.sub(r"<[^>]+>", "", label))
        if not href or not title:
            continue
        out.append({"url": BASE + href if href.startswith("/") else href, "title": title,
                    "kind": "listing" if "/list/" in href else "product"})
    return out


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    t_all = text(page)
    if meta is not None:
        m = re.search(r"знайдено\s*(\d+)\s*товар", t_all)
        if m:
            meta["total_est"] = to_int(m.group(1))
    arts = re.split(r"<article[^>]*model-short-div", page)[1:]
    if not arts and "ek-item.php" in page[:4000] and "<h1" in page:
        rows = _item_page(page)
        if meta is not None and rows:
            meta["total_est"] = 1
        return rows
    out = []
    for c in arts:
        a = re.search(r"model-short-title[^>]*href='([^']+)'[^>]*title='([^']+)'", c) or \
            re.search(r'model-short-title[^>]*href="([^"]+)"[^>]*title="([^"]+)"', c)
        if not a:
            continue
        t = text(c)
        # two listing dialects: "Ціни 12 від A до B грн" (search) and "Ціна від A до B грн" (category)
        rng = re.search(r"Ціни\s*(\d+)\s*від\s*([\d\s\u00a0]+)\s*до\s*([\d\s\u00a0]+)\s*грн", t)
        if not rng:
            m2 = re.search(r"Ціна\s*від\s*([\d\s\u00a0]+)\s*до\s*([\d\s\u00a0]+)\s*грн", t)
            if m2:
                rng = type("M", (), {"group": staticmethod(lambda i, a=m2: {1: None, 2: a.group(1), 3: a.group(2)}[i])})()
        one = re.search(r"Ціни?\s*(\d+)?\s*([\d\s\u00a0]{4,})\s*грн", t) if not rng else None
        cnt = re.search(r"Відгуки\s*(\d+)", t)
        # spec = the card's description block, cut before the media/price tail.
        # Category-agnostic: works for мониторы, пральні машини, кавомашини alike.
        desc = re.search(r'class="model-short-description"(.*?)(?:<div class="model-short-price|<table|$)', c, re.S)
        spec_text = text(desc.group(1)) if desc else ""
        spec_text = spec_text.lstrip("> ").strip()
        spec = re.split(r"\s(?:Фото|Відео|Інструкці|Відгуки|Ціни|Порівняти)\b", spec_text)[0].strip()
        out.append({
            "group": GROUP, "source": SITE, "title": text(a.group(2)), "model": model_from_title(text(a.group(2))),
            "url": BASE + a.group(1),
            "price_min_uah": to_int(rng.group(2)) if rng else (to_int(one.group(2)) if one else None),
            "price_max_uah": to_int(rng.group(3)) if rng else (to_int(one.group(2)) if one else None),
            "offers_count": to_int(rng.group(1)) if rng else (to_int(one.group(1)) if one else None),
            "rating_count": to_int(cnt.group(1)) if cnt else None,
            "availability": "" if (rng or one) else "нет предложений",
            "delivery_scope": "ua_local",
            "notes": spec[:240],
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    """Suggest → listing pages (captcha-free path). Falls back to ek-list.php only if suggest
    yields nothing; a captcha there raises FetchError so the caller can skip the source."""
    r = get(SUGGEST.format(q=quote_plus(query)), accept="text/html, */*;q=0.8",
            headers=(f"Referer: {BASE}/ua/", "X-Requested-With: XMLHttpRequest"))
    if r.blocked:
        raise FetchError(f"ekatalog suggest blocked ({r.status})")
    hints = parse_suggest(r.text)
    if meta is not None:
        meta["suggestions"] = [h["title"] for h in hints[:8]]
    rows: list[dict] = []
    seen: set[str] = set()
    for hint in [h for h in hints if h["kind"] == "listing"][:MAX_LISTINGS]:
        page = get(hint["url"], headers=(f"Referer: {BASE}/ua/",))
        if page.blocked:
            continue
        for row in parse_search(page.text, meta if not rows else None):
            if row["url"] not in seen:
                seen.add(row["url"])
                rows.append(row)
    if rows:
        return rows
    for hint in [h for h in hints if h["kind"] == "product"][:3]:
        page = get(hint["url"], headers=(f"Referer: {BASE}/ua/",))
        if not page.blocked:
            rows += [row for row in _item_page(page.text) if row["url"] not in seen]
    if rows:
        return rows
    fallback = get(SEARCH.format(q=quote_plus(query)), headers=(f"Referer: {BASE}/ua/",))
    if fallback.blocked:
        raise FetchError(f"ekatalog blocked ({fallback.status}); подсказка не дала результатов")
    return parse_search(fallback.text, meta)
