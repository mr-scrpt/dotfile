"""ek.ua (E-Katalog) — aggregator. Server-rendered; curl passes.
  search: /ua/ek-list.php?search_=<q>&_a=1 → "знайдено N товар(ів)", <article class="model-short-div">
          with <a class='model-short-title' href='/ua/<SLUG>.htm' title='…' data-idgood=…>, spec text,
          "Відгуки N", "Ціни K від A до B грн". An exact model query may 302 to the product page
          (ek-item.php) — then `parse_search` returns that single item.
"""
from __future__ import annotations

import re
from urllib.parse import quote_plus

from ...http import FetchError, get, text, to_int

SITE, GROUP = "ekatalog", "aggregator"
BASE = "https://ek.ua"
SEARCH = BASE + "/ua/ek-list.php?search_={q}&_a=1"


def _item_page(page: str) -> list[dict]:
    """Exact-match redirect landed on a product page."""
    t = text(page)
    title = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
    idg = re.search(r"ek-item\.php\?idg_=(\d+)", page)
    rng = re.search(r"від\s*([\d\s\u00a0]+)\s*до\s*([\d\s\u00a0]+)\s*грн", t)
    cnt = re.search(r"Відгуки\s*(\d+)", t)
    if not title:
        return []
    return [{"group": GROUP, "source": SITE, "title": text(title.group(1)), "url": f"{BASE}/ua/ek-item.php?idg_={idg.group(1)}" if idg else BASE,
             "price_min_uah": to_int(rng.group(1)) if rng else None, "price_max_uah": to_int(rng.group(2)) if rng else None,
             "rating_count": to_int(cnt.group(1)) if cnt else None, "delivery_scope": "ua_local"}]


COLOURS = r"(чорний|білий|сірий|срібляст\w*|синій|червоний|зелений|рожевий|золот\w*|фіолет\w*|blue|black|white|silver|gr[ae]y)"


def model_from_title(title: str) -> str:
    """'Монітор Asus ROG Strix OLED XG27AQDPG 26.5 " чорний' → 'Asus ROG Strix OLED XG27AQDPG'.
    Drops the leading type word, and everything from a size ('26.5 "', '27 ″') or colour on."""
    t = re.sub(r"\s+", " ", title).strip()
    t = re.sub(r"^[А-ЯІЇЄA-Z][а-яіїєa-z]+(?:\s+[а-яіїєa-z]+)?\s+(?=[A-Z0-9])", "", t)       # "Монітор ", "Зарядний пристрій "
    t = re.split(r"\s\d+(?:[.,]\d+)?\s*(?:\"|″|дюйм)", t)[0]
    t = re.split(r"\s" + COLOURS + r"\b", t, flags=re.I)[0]
    return t.strip(" ,")


def parse_search(page: str, meta: dict | None = None) -> list[dict]:
    t_all = text(page)
    if meta is not None:
        m = re.search(r"знайдено\s*(\d+)\s*товар", t_all)
        meta["total_est"] = to_int(m.group(1)) if m else None
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
        rng = re.search(r"Ціни\s*(\d+)\s*від\s*([\d\s\u00a0]+)\s*до\s*([\d\s\u00a0]+)\s*грн", t)
        one = re.search(r"Ціни\s*(\d+)\s*([\d\s\u00a0]{4,})\s*грн", t) if not rng else None
        cnt = re.search(r"Відгуки\s*(\d+)", t)
        spec = re.search(r"(Екран:.*?)(?:Відгуки|Відео|Фото|Ціни|$)", t)
        out.append({
            "group": GROUP, "source": SITE, "title": text(a.group(2)), "model": model_from_title(text(a.group(2))),
            "url": BASE + a.group(1),
            "price_min_uah": to_int(rng.group(2)) if rng else (to_int(one.group(2)) if one else None),
            "price_max_uah": to_int(rng.group(3)) if rng else (to_int(one.group(2)) if one else None),
            "offers_count": to_int(rng.group(1)) if rng else (to_int(one.group(1)) if one else None),
            "rating_count": to_int(cnt.group(1)) if cnt else None,
            "availability": "" if (rng or one) else "нет предложений",
            "delivery_scope": "ua_local",
            "notes": text(spec.group(1))[:200] if spec else "",
        })
    return out


def search(query: str, meta: dict | None = None) -> list[dict]:
    r = get(SEARCH.format(q=quote_plus(query)))
    if r.blocked:
        raise FetchError(f"ekatalog blocked ({r.status})")
    return parse_search(r.text, meta)
