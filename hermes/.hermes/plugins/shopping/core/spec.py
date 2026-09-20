"""Layer 1 — spec: STRUCTURE ONLY. Knows nothing about products, units, categories or languages.

The plugin does three mechanical things:

    parse(line)               "Ключ: значення; тег; Ключ2: значення2" → pairs + flags
    observe(lines)            which keys this result set has, their real values, and — grouped by
                              the RAW unit token — the numeric range actually seen
    evaluate(line, criteria)  check criteria against those pairs

All semantics live in `criteria`, authored by the MODEL after it has seen `observe()` output,
i.e. after it has seen how this particular category spells its values. A criterion:

    {"key": "потужність",                                  # loose match against the spec's keys
     "any_of": [{"min": 2000, "max": 3000, "unit": "Вт"},  # alternative spellings the model saw
                {"min": 2, "max": 3, "unit": "кВт"}],
     "contains": ["синус"],                                # and/or a substring test
     "label": "2–3 кВт, чистый синус"}                     # wording for the user and the report

Units are compared as opaque strings (case/punctuation-insensitive); with no `unit` the number
is compared regardless of unit. NOTHING is converted and no unit, prefix or synonym is ever
enumerated here, so a unit nobody has seen yet (Нм, люмен, psi, dpi) needs no code change — the
model writes the alternatives it observed.
"""
from __future__ import annotations

import re
import unicodedata

# A unit is whatever token trails the number — never enumerated.
# A '-' straight after a digit is a range separator ("220-230 В"), not a minus sign.
# The unit token may itself contain '/' ("кд/м²", "об/хв") — but '/' between two NUMBERS is a
# separator ("12/24 В"), so a slash is part of the unit only when a digit does not follow it.
NUM_RE = re.compile(r"((?<![\d,.])-?\d+(?:[.,]\d+)?)\s*"
                    r"((?:[^\W\d_]|[°%\"″·])(?:[^\s,;()/]|/(?!\d)){0,14})?(?=[\s,;()]|/\d|-\d|$)")
# "Ключ: " — a few words ending at a colon.
KEY_RE = re.compile(r"(?:^|[;\u2022]\s*|\s)([A-Za-zА-Яа-яІЇЄҐіїєґ][\w'’\-()/ ]{1,45}?):\s*")
SHAPE_RE = re.compile(r"\d\s*[xх×]\s*\d")      # 2560x1440, 520 x 240 x 220 — not a scalar
EQ_TOLERANCE = 0.02


def norm(s: str) -> str:
    """Casefold + drop accents/punctuation so keys and units compare forgivingly."""
    s = unicodedata.normalize("NFKD", str(s or "")).casefold()
    return re.sub(r"[^\w\s·°%\"/]", " ", s).strip()


def norm_unit(u: str) -> str:
    """A unit is an opaque string; only spelling noise is removed."""
    return re.sub(r"[\s.]", "", norm(u))


def numbers(value: str, first_part_only: bool = False) -> list[dict]:
    """Every scalar of a value with its raw unit token.

    'Mini LED IPS, відгук 1 мс, 180 Гц' → [{1,'мс'}, {180,'Гц'}] — one value often carries several
    facts, and a criterion picks its own by unit. Shapes (2560x1440) are never scalars; a number
    without its own unit borrows its part's only unit ('12/24 В').
    `first_part_only` keeps the old "leading fact" behaviour for display helpers.
    """
    whole = str(value or "").replace("\u00a0", " ")
    out: list[dict] = []
    for part in re.split(r",(?!\d)|[()]", whole):
        v = part.strip()
        if not v or SHAPE_RE.search(v):
            continue
        found = [(float(m.group(1).replace(",", ".")), (m.group(2) or "").strip(" .,"))
                 for m in NUM_RE.finditer(v)]
        if not found:
            continue
        units = {u for _, u in found if u}
        fallback = next(iter(units)) if len(units) == 1 else ""
        out += [{"n": n, "unit": u or fallback} for n, u in found]
        if first_part_only:
            break
    return out


def _split_key(key: str, after_value: bool) -> tuple[str, str]:
    """(clean key, tail that belongs to the PREVIOUS value).
    'Гц Відображення кольорів' → ('Відображення кольорів', 'Гц') — the unit trails 280, not the key."""
    clean = _clean_key(key, after_value)
    tail = key[: len(key) - len(clean)].strip() if clean and key.endswith(clean) else ""
    return clean, tail


def _clean_key(key: str, tail_of_previous_value: bool = False) -> str:
    """Strip tokens that belong to the PREVIOUS value, not to this key:
    '280 Гц Відображення кольорів' → 'Відображення кольорів'. Only a leading NUMBER (and the unit
    token right after it) is stripped, so real multi-word keys ('вхідна напруга') stay intact."""
    words = key.split()
    while words and re.fullmatch(r"-?\d+(?:[.,]\d+)?", words[0]):
        words.pop(0)                                   # the number itself
        if words and len(words) > 1 and len(words[0]) <= 6 and re.fullmatch(r"[^\W\d_]+", words[0]):
            words.pop(0)                               # its unit
    # after a value, a short lowercase-or-unit lead-in token is that value's tail, not a key word
    if tail_of_previous_value and len(words) > 1 and len(words[0]) <= 6 and re.fullmatch(r"[^\W\d_]+", words[0]):
        words.pop(0)
    return " ".join(words).strip(" -–—,")


def parse(line: str) -> dict:
    """Spec line → {"pairs": {key: value}, "flags": [bare tokens], "raw": line}.

    Segments split on ';' (hotline style); inside a segment inline 'Ключ: значення' runs are
    detected (e-katalog style); a segment with no key at all becomes a flag.
    """
    raw = re.sub(r"\s+", " ", str(line or "")).strip()
    if not raw:
        return {"pairs": {}, "flags": [], "raw": "", "described": False}
    pairs: dict[str, str] = {}
    flags: list[str] = []
    for segment in (seg.strip() for seg in raw.split(";")):
        if not segment:
            continue
        raw_marks = list(KEY_RE.finditer(segment))
        marks = []
        for i, m in enumerate(raw_marks):
            # a key that starts right where the previous value ended may have swallowed its tail
            clean, tail = _split_key(m.group(1), i > 0)
            marks.append((m.start(1), m.end(0), clean, tail))
        marks = [m for m in marks if m[2]]
        if not marks:
            flags += [t.strip() for t in segment.split(",") if t.strip()]
            continue
        head = segment[: marks[0][0]].strip(" ,")
        if head:
            flags += [t.strip() for t in head.split(",") if t.strip()]
        for i, (_, val_start, key, _tail) in enumerate(marks):
            end = marks[i + 1][0] if i + 1 < len(marks) else len(segment)
            value = segment[val_start:end].strip(" ,.")
            if i + 1 < len(marks) and marks[i + 1][3]:
                value = f"{value} {marks[i + 1][3]}".strip()      # give the unit back to this value
            if key and value:
                pairs.setdefault(key, value)
    return {"pairs": pairs, "flags": flags, "raw": raw, "described": bool(pairs)}


def facts(source) -> dict:
    """One row → ONE flat namespace of stated facts, in the same shape as :func:`parse`.

    A row states things in two shapes: a free-text spec line, and its own scalar fields. Neither is
    privileged, and this module knows NO field name — whatever a source happens to store (price
    today, length and colour tomorrow) becomes an addressable key, `observe` reports what is really
    there, and the model writes criteria against it. Structural rules only:

    * text values are parsed as spec text (a locator — anything containing "://" — is skipped, it
      is an address, not prose);
    * numeric values become a key with the number as its value and no unit token, so a criterion
      for them is written with `unit: ""`;
    * booleans / nested structures are ignored — they state nothing comparable.
    """
    if not isinstance(source, dict):
        return parse(source)
    pairs: dict[str, str] = {}
    flags: list[str] = []
    chunks: list[str] = []
    described = False
    for key, value in source.items():
        if isinstance(value, bool) or value is None:
            continue
        if isinstance(value, (int, float)):
            pairs.setdefault(str(key), str(value))
        elif isinstance(value, str) and value.strip() and "://" not in value:
            part = parse(value)
            for k, v in part["pairs"].items():
                pairs.setdefault(k, v)
            flags += part["flags"]
            chunks.append(part["raw"])
            described = described or part["described"]
    return {"pairs": pairs, "flags": flags, "raw": " ".join(c for c in chunks if c),
            "described": described}


def find(pairs: dict, key: str) -> tuple[str | None, str | None]:
    """Criterion key → (actual key, value) by loose substring; the most specific key wins."""
    want = norm(key)
    hits = [(k, v) for k, v in pairs.items() if want and (want in norm(k) or norm(k) in want)]
    if not hits:
        return None, None
    return max(hits, key=lambda kv: len(norm(kv[0])))


def _rule_ok(nums: list[dict], rule: dict) -> bool:
    lo, hi = rule.get("min", float("-inf")), rule.get("max", float("inf"))
    unit = norm_unit(rule.get("unit", ""))
    eq = rule.get("eq")
    for item in nums:
        if unit and norm_unit(item["unit"]) != unit:
            continue
        if eq is not None:
            if abs(item["n"] - float(eq)) <= abs(float(eq)) * EQ_TOLERANCE:
                return True
        elif lo <= item["n"] <= hi:
            return True
    return False


def check(spec: dict, criterion: dict) -> tuple[bool | None, str]:
    """(True | False | None = the spec does not state it, human explanation).

    A criterion may be a GROUP: {"label": "…", "either": [criterion, criterion, …]} passes when
    ANY branch passes — that is how "OLED или Mini-LED" is expressed, since a site may spell the
    two in different keys (Матриця: QD-OLED vs Матриця: Mini LED IPS) or only in the title.
    """
    branches = criterion.get("either")
    if branches:
        label = criterion.get("label") or " / ".join(b.get("label") or b.get("key", "?") for b in branches)
        results = [check(spec, b) for b in branches]
        if any(ok is True for ok, _ in results):
            why = next(w for ok, w in results if ok is True)
            return True, f"{label}: {why}"
        if all(ok is None for ok, _ in results):
            return None, f"{label}: ни одна ветка не указана в спеке"
        return False, f"{label}: " + "; ".join(w for ok, w in results if ok is False)[:110]
    key = criterion.get("key") or ""
    label = criterion.get("label") or key or "критерий"
    actual_key, value = find(spec["pairs"], key)
    haystack = " ".join([spec["raw"], *spec["flags"]])
    rules = criterion.get("any_of")
    if not rules and any(k in criterion for k in ("min", "max", "eq")):
        rules = [criterion]
    contains = criterion.get("contains") or []
    if rules:
        if value is None:
            return None, f"{label}: не указано"
        nums = numbers(value)
        if not nums:
            return None, f"{label}: «{value}» без числа"
        ok = any(_rule_ok(nums, r) for r in rules)
        return ok, f"{actual_key}: {value}" + ("" if ok else f" ≠ {label}")
    if contains:
        hay, whole = norm(value if value is not None else haystack), norm(haystack)
        ok = any(norm(c) in hay or norm(c) in whole for c in contains)
        if not ok and value is None and not spec.get("described"):
            return None, f"{label}: спека пустая"
        return ok, f"{actual_key or 'спека'}: " + ("есть" if ok else "нет") + f" «{'/'.join(contains)}»"
    return None, f"{label}: пустой критерий"


def evaluate(source, criteria: list[dict] | None, strict: bool = False) -> tuple[bool, list[str], list[str]]:
    """Apply the model's criteria to one row → (keep, failed, unverifiable).

    `source` is a spec line or a whole row (see :func:`facts`): criteria address everything the row
    states, with no distinction between "a parameter" and "a field of the card".

    A criterion the row is silent about does NOT reject it (aggregator specs are patchy): it is
    reported instead, unless `strict`.
    """
    if not criteria:
        return True, [], []
    spec = facts(source)
    failed, unknown = [], []
    for criterion in criteria:
        ok, why = check(spec, criterion)
        if ok is False:
            failed.append(why)
        elif ok is None:
            unknown.append(why)
    return (not failed and (not unknown or not strict)), failed, unknown


def observe(rows: list, top: int = 6, min_share: float = 0.1) -> list[dict]:
    """What this result set actually contains — the material the model needs to author criteria.

    → [{"key", "coverage", "values": [{value, count}], "units": [{unit, min, max, count}]}]
    Numeric summaries are grouped BY RAW UNIT TOKEN and never converted, so the model can see
    that the category spells power both as "2000 Вт" and "3 кBт" and cover both in `any_of`.
    """
    total = max(len(rows), 1)
    buckets: dict[str, dict] = {}
    for row in rows:
        for k, v in facts(row)["pairs"].items():
            b = buckets.setdefault(norm(k), {"key": k, "count": 0, "values": {}, "units": {}})
            b["count"] += 1
            b["values"][v] = b["values"].get(v, 0) + 1
            for item in numbers(v):
                u = b["units"].setdefault(norm_unit(item["unit"]),
                                          {"unit": item["unit"], "min": item["n"], "max": item["n"], "count": 0})
                u["min"], u["max"] = min(u["min"], item["n"]), max(u["max"], item["n"])
                u["count"] += 1
    out = []
    for b in buckets.values():
        if b["count"] / total < min_share:
            continue
        item = {"key": b["key"], "coverage": round(b["count"] / total, 2),
                "values": [{"value": v, "count": c}
                           for v, c in sorted(b["values"].items(), key=lambda kv: -kv[1])[:top]]}
        if b["units"]:
            item["units"] = sorted(b["units"].values(), key=lambda u: -u["count"])[:4]
        out.append(item)
    return sorted(out, key=lambda x: (-x["coverage"], x["key"]))


def describe(criteria: list[dict] | None) -> list[str]:
    """Criteria → plain lines for showing the user before the search runs."""
    out = []
    for c in criteria or []:
        label = c.get("label")
        if not label:
            parts = []
            for r in (c.get("any_of") or ([c] if any(k in c for k in ("min", "max", "eq")) else [])):
                if r.get("eq") is not None:
                    parts.append(f"= {r['eq']:g} {r.get('unit', '')}".strip())
                else:
                    lo = f"{r['min']:g}" if "min" in r else "…"
                    hi = f"{r['max']:g}" if "max" in r else "…"
                    parts.append(f"{lo}–{hi} {r.get('unit', '')}".strip())
            if c.get("contains"):
                parts.append("/".join(c["contains"]))
            label = ", ".join(parts) or "—"
        out.append(f"{c.get('key', '?')}: {label}" + ("" if c.get("required", True) else " (желательно)"))
    return out
