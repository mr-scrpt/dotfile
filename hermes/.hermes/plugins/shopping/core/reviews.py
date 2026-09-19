"""Layer 2 — reviews service: scripted collection of buyer reviews from marketplace cards, condensed
into a token-cheap digest. The model never sees raw review lists; it gets:

    {"model", "sources": [{site, url, total, avg, distribution:{5:..,1:..}, verified_share}],
     "signals": [{"site", "rating", "text"}]}          # only sentences that carry information

Fetcher contract (optional per site):  reviews(url) -> {"total": int|None, "avg": float|None,
    "distribution": {5: n, …} | None, "reviews": [{"rating": 1-5|None, "text", "pros", "cons",
    "verified": bool}]}.   Sites without it are skipped silently.

"Signal" = a sentence from a review that mentions a concrete property/problem (matte, flicker,
noise, warranty, dead pixel, …) or comes from a ≤3-star review; generic praise ("все супер",
"рекомендую", "швидка доставка") is dropped. Digest size is capped by MAX_SIGNAL_CHARS.
"""
from __future__ import annotations

import re
from concurrent.futures import ThreadPoolExecutor, as_completed

from . import findings, sessions, sources

MAX_SIGNAL_CHARS = 2500
MAX_SIGNALS = 25
MIN_TEXT = 25

# generic, information-free phrases (uk/ru) — a sentence made only of these is noise
NOISE = re.compile(r"^(?:\W|все|всё|супер|топ|клас|класс|дякую|спасибо|рекомендую|раджу|задоволен\w*|доволен\w*|"
                   r"чудов\w*|відмінн\w*|отличн\w*|гарн\w*|хорош\w*|норм\w*|швидк\w* доставк\w*|быстр\w* доставк\w*|"
                   r"працює|работает|подобається|нравится|за свої гроші|за свои деньги|100%|ок|okay|good|nice|\d+|\s)+$", re.I)
# words that make a sentence worth keeping even in a 5-star review
SIGNAL = re.compile(r"засвіт|засвет|мерехт|мерца|flicker|шум|скрип|люфт|бр[ао]к|битий|битый|піксел|пиксел|гарант|сервіс|сервис|"
                    r"грі[єе]|греет|нагрів|нагрев|coil|свист|гуде|відблиск|блик|матов|глянц|яскрав|ярк|фрінж|fringe|текст|шрифт|"
                    r"кут|угол|кабел|блок живлення|бп|підставк|подставк|регулюв|регулир|hdr|vrr|g-sync|freesync|затримк|задержк|"
                    r"батаре|акум|аккум|зарядк|нагріваєт|тормоз|глюч|зависа|лаг|звук|динамік|динамик|камер|екран|экран|дисплей|"
                    r"пластик|корпус|комплект|коробк|відновлен|восстановлен|подряпин|царапин|не працю|не работа|злама|слома|"
                    r"повернув|вернул|обмін|обмен|проблем|недолік|недостат|мінус|минус|але|но |однак|однако|жаль|шкода", re.I)


def _sentences(t: str) -> list[str]:
    return [s.strip(" .!;,-–") for s in re.split(r"(?<=[.!?…])\s+|\n+", t or "") if s.strip()]


def condense(site: str, url: str, data: dict) -> tuple[dict, list[dict]]:
    """Per-site summary + signal sentences from one fetcher result."""
    revs = data.get("reviews") or []
    rated = [r for r in revs if r.get("rating")]
    dist = data.get("distribution")
    if not dist and rated:
        dist = {}
        for r in rated:
            dist[int(round(r["rating"]))] = dist.get(int(round(r["rating"])), 0) + 1
    avg = data.get("avg")
    if avg is None and rated:
        avg = round(sum(r["rating"] for r in rated) / len(rated), 2)
    summary = {"site": site, "url": url, "total": data.get("total") if data.get("total") is not None else len(revs),
               "fetched": len(revs), "avg": avg, "distribution": {int(k): v for k, v in (dist or {}).items()} or None,
               "verified_share": round(sum(1 for r in revs if r.get("verified")) / len(revs), 2) if revs else None}
    signals = []
    seen: set[str] = set()
    for r in revs:
        low = (r.get("rating") or 5) <= 3
        for field, tag in (("cons", "−"), ("pros", "+"), ("text", "")):
            for s in _sentences(r.get(field) or ""):
                if len(s) < MIN_TEXT or NOISE.match(s):
                    continue
                if not (low or tag == "−" or SIGNAL.search(s)):
                    continue
                key = findings.normalize_model(s)[:60]
                if key in seen:
                    continue
                seen.add(key)
                signals.append({"site": site, "rating": r.get("rating"), "text": (tag + " " if tag else "") + s[:240]})
    return summary, signals


def _fetch_one(site: str, url: str) -> tuple:
    try:
        mod = sources.get(site).module()
    except KeyError:
        return site, url, None, "unknown site"
    fn = getattr(mod, "reviews", None)
    if not callable(fn):
        return site, url, None, "no reviews() in fetcher"
    try:
        return site, url, fn(url), None
    except Exception as e:  # noqa: BLE001
        return site, url, None, f"{type(e).__name__}: {e}"[:120]


def collect(topic: str, session: str, model: str, sites: list[str] | None = None, store: bool = True) -> dict:
    """Reviews for `model` from every stored marketplace/aggregator finding of that model (one URL per
    site, the first stored), in parallel; stores one `review` finding per site with the digest."""
    meta, sp = sessions.load(topic, session)
    if meta is None:
        return sessions.not_found(topic, session)
    rows = [f for f in findings.list_(topic, session, model=model)["findings"] if f["group"] in ("marketplace", "aggregator")]
    best: dict[str, dict] = {}                         # per site: the offer with the most reviews
    for f in rows:
        if sites and f["source"] not in sites:
            continue
        if not f.get("rating_count") and f["source"] != "hotline":
            continue                                   # the card says 0 reviews — skip the request
        if f["source"] not in best or (f.get("rating_count") or 0) > (best[f["source"]].get("rating_count") or 0):
            best[f["source"]] = f
    targets = {site: f["url"] for site, f in best.items()}
    if not targets:
        return {"success": True, "model": model, "sources": [], "signals": [], "note": "no stored offers with reviews for this model"}
    summaries, signals, errors = [], [], []
    with ThreadPoolExecutor(max_workers=min(6, len(targets))) as pool:
        futs = [pool.submit(_fetch_one, s, u) for s, u in targets.items()]
        for fu in as_completed(futs, timeout=120):
            site, url, data, err_ = fu.result()
            if data is None:
                if err_ and "no reviews()" not in err_:
                    errors.append({"site": site, "error": err_})
                continue
            summ, sig = condense(site, url, data)
            summaries.append(summ)
            signals.extend(sig)
    signals.sort(key=lambda s: (s["rating"] or 5, -len(s["text"])))
    budget, kept = MAX_SIGNAL_CHARS, []
    for s in signals:
        if len(kept) >= MAX_SIGNALS or budget - len(s["text"]) < 0:
            break
        kept.append(s)
        budget -= len(s["text"])
    if store:
        review_rows = []
        for summ in summaries:
            if not summ["fetched"] and not summ["total"]:
                continue
            site_sig = [s["text"] for s in kept if s["site"] == summ["site"]]
            # own dedup key: the offer row already owns the bare card URL
            review_rows.append({"group": "review", "source": f"{summ['site']}-reviews", "model": model,
                                "url": summ["url"] + ("&" if "?" in summ["url"] else "?") + "reviews=1",
                                "rating": summ["avg"], "rating_count": summ["total"], "model_match": "exact",
                                "nuances": [t.lstrip("−+ ") for t in site_sig if t.startswith("−") or (SIGNAL.search(t) and not t.startswith("+"))][:8],
                                "pros": [t.lstrip("+ ") for t in site_sig if t.startswith("+")][:5],
                                "notes": f"{summ['fetched']} из {summ['total']} прочитано скриптом; распределение "
                                         + (", ".join(f"{k}★:{v}" for k, v in sorted((summ['distribution'] or {}).items(), reverse=True)) or "—")})
        stored = findings.add(topic, session, review_rows) if review_rows else {"added": 0, "merged": 0}
        sessions.log_event(topic, session, "source_done",
                           f"reviews {model}: {len(summaries)} sites, {sum(s['fetched'] for s in summaries)} texts, {len(kept)} signals")
    else:
        stored = {"added": 0, "merged": 0}
    return {"success": True, "model": model, "sources": summaries, "signals": kept, "errors": errors,
            "stored": {k: stored.get(k) for k in ("added", "merged")}}
