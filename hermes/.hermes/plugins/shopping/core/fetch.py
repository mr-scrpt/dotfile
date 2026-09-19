"""Layer 2 — fetch service: run a site fetcher, keep only hits that match the model code, store as
findings, return a compact summary. This is what keeps raw HTML/JSON out of the model context."""
from __future__ import annotations

import re

from . import findings, sessions, sources
from .fs import err, now

MAX_REVIEW_CHARS = 350


def _tokens(model: str) -> list[str]:
    """Model-code tokens that must all appear in a title: 'MSI MAG 274QP QD-OLED X24' →
    ['274QP', 'QD-OLED', 'X24'] (drops brand-ish first token and 1-2 char noise)."""
    toks = [t for t in findings.normalize_model(model).split() if t] if " " in model else []
    raw = [t for t in model.replace("/", " ").split() if len(t) > 2]
    return raw[1:] if len(raw) > 2 else raw


# Variant words that turn a model into a different product when they appear in the title but not
# in the query (iPhone 16 Pro ≠ iPhone 16 Pro Max; Galaxy S25 ≠ S25 Ultra/+).
VARIANT_WORDS = ("MAX", "PLUS", "ULTRA", "MINI", "LITE", "AIR", "PRO", "FE", "NEO", "TI", "SUPER", "XT", "XL")


def _words(s: str) -> list[str]:
    return [w for w in re.split(r"[\s,()/]+", (s or "").upper().replace("+", " PLUS ")) if w]


def matches_model(title: str, model: str) -> bool:
    """Every model token appears in the title (spacing/dash-insensitive) AND the title does not add
    a variant word (Max/Plus/Ultra/…) right after the matched model span that the query lacks."""
    nt = findings.normalize_model(title)
    if not all(findings.normalize_model(t) in nt for t in _tokens(model)):
        return False
    q_words = set(_words(model))
    t_words = _words(title)
    anchor = [i for i, w in enumerate(t_words) if any(findings.normalize_model(w) == findings.normalize_model(t) for t in _tokens(model))]
    if not anchor:
        return True
    # words immediately after the last matched model token, before a size/capacity/colour word
    for w in t_words[max(anchor) + 1: max(anchor) + 3]:
        if w in VARIANT_WORDS and w not in q_words:
            return False
        if re.match(r"^\d+(GB|ГБ|TB|ТБ)?$", w) or not w.isalpha():
            break
    return True


# Accessory categories: a card in one of these is never the product itself, even when its title
# carries the full model code ("Захисне скло для iPhone 16 Pro 256Gb"). Matched case-insensitively
# as substrings of the site's category name (uk/ru).
ACCESSORY_CATEGORIES = ("чохл", "чехл", "скло", "стекл", "плівк", "пленк", "кабел", "зарядн", "підставк", "подставк",
                        "кріплен", "креплен", "сумк", "аксесуар", "аксессуар", "адаптер", "перехідник", "переходник",
                        "тримач", "держател", "спрей", "серветк", "салфетк", "наклейк", "ремінц", "ремешк")


USED_RE = re.compile(r"\b(б/у|бу|вживан\w*|відновлен\w*|восстановлен\w*|refurbished|renewed|уцін\w*|уцен\w*)\b", re.I)


def is_used(title: str) -> bool:
    return bool(USED_RE.search(title or ""))


def category_ok(card_category: str, wanted: str | None) -> tuple[bool, str]:
    """(keep?, reason). `wanted` = the category the user picked from the probe (may be empty).
    Cards whose category is an accessory are dropped; when `wanted` is given the card's category
    must match it (substring either way); unknown category is kept (title match still applies)."""
    cat = (card_category or "").strip().lower()
    if not cat:
        return True, ""
    if any(k in cat for k in ACCESSORY_CATEGORIES):
        return False, f"accessory category «{card_category}»"
    if wanted:
        w = wanted.strip().lower()
        if w and w not in cat and cat not in w:
            return False, f"category «{card_category}» ≠ «{wanted}»"
    return True, ""


def _compact_offer(f: dict) -> dict:
    keys = ("source", "title", "url", "price_uah", "price_note", "price_min_uah", "price_max_uah", "rating", "rating_count",
            "offers_count", "availability", "seller", "installment", "installment_note", "delivery_scope", "category")
    return {k: f[k] for k in keys if f.get(k) not in (None, "", [])}


def fetch(topic: str, session: str, site: str, model: str, geo: str = "ua_local", limit: int = 5,
          store: bool = True, category: str | None = None, condition: str | None = None) -> dict:
    """Search `site` for `model`, keep hits whose title carries the model code AND whose site
    category is the product itself (accessories are dropped; `category` — from the probe menu —
    must match when given), store as findings, return compact offers plus review texts (rozetka)
    / per-shop offers (hotline) for the model to read."""
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    try:
        mod = sources.get(site).module()
    except KeyError as e:
        return err(str(e))
    try:
        hits = mod.search(model, limit=limit) if site == "rozetka" else mod.search(model)
    except Exception as e:  # noqa: BLE001
        sessions.log_event(topic, session, "source_blocked", f"{site}: {model}: {e}")
        return err(f"{site} failed: {e}", site=site, model=model)
    matched = [h for h in hits if matches_model(h.get("title") or "", model)]
    dropped = []
    keep = []
    condition = condition or (meta.get("params") or {}).get("condition") or "new"
    category = category or (meta.get("params") or {}).get("category") or None
    for h in matched:
        ok, why = category_ok(h.get("category") or "", category)
        if ok and condition == "new" and is_used(h.get("title") or ""):
            ok, why = False, "б/у или восстановленный (condition=new)"
        (keep if ok else dropped).append((h, why))
    matched = [h for h, _ in keep]
    if geo == "ua_local":
        matched = [h for h in matched if h.get("delivery_scope", "ua_local") == "ua_local"]
    matched = matched[:limit]
    extras = {}
    rows = []
    allowed = set(findings.defaults())
    for h in matched:
        h = dict(h)
        h["model"] = model
        reviews = h.pop("reviews", None)
        spec = h.pop("spec", None)
        if spec and not h.get("notes"):
            h["notes"] = "; ".join(f"{k}={v}" for k, v in spec.items() if v is not None)
        h = {k: v for k, v in h.items() if k in allowed}
        if reviews:
            extras.setdefault("reviews", []).extend(
                {"mark": r["mark"], "pros": r["pros"][:MAX_REVIEW_CHARS], "cons": r["cons"][:MAX_REVIEW_CHARS],
                 "text": r["text"][:MAX_REVIEW_CHARS]} for r in reviews)
        rows.append(h)
    if site == "hotline" and matched:
        try:
            off = mod.offers(matched[0]["url"])
            extras["shops"] = [{k: o[k] for k in ("shop", "price_uah", "installment_note", "guarantee", "shop_reviews", "from") if o.get(k) not in (None, "")}
                               for o in off["offers"][:12]]
            with_inst = sorted({o["shop"] for o in off["offers"] if o["installment"]})
            rows[0]["installment"] = bool(with_inst)
            rows[0]["installment_note"] = f"{len(with_inst)} из {len(off['offers'])} магазинов: " + ", ".join(with_inst[:6]) if with_inst else ""
        except Exception as e:  # noqa: BLE001
            extras["shops_error"] = str(e)
    stored = findings.add(topic, session, rows) if store and rows else {"added": 0, "merged": 0, "errors": []}
    if stored.get("errors"):
        sessions.log_event(topic, session, "note", f"{site}: {len(stored['errors'])} rows rejected: {stored['errors'][0]['error'][:120]}")
    sessions.log_event(topic, session, "source_done",
                       f"{site}: {model}: {len(hits)} hits, {len(matched)} matched, {len(dropped)} dropped (category/condition)")
    return {"success": True, "site": site, "model": model, "hits": len(hits), "matched": len(matched),
            "dropped": [{"title": (h.get("title") or "")[:70], "why": why} for h, why in dropped[:5]],
            "stored": {k: stored.get(k) for k in ("added", "merged")} | ({"rejected": len(stored["errors"])} if stored.get("errors") else {}),
            "offers": [_compact_offer(r) for r in rows], **extras}
