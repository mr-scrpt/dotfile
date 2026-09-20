"""Layer 1 — specs: parse an aggregator's short characteristics line into key→value pairs,
match user constraints against them, and summarise which parameters a category even has.

Nothing here knows what a product is. A spec line is any mix of

    "дисплей: 27\"; IPS; 2560x1440; частота оновлення: 240 Гц"          (hotline, ';' separated)
    "Екран: 26.5 \", 2560x1440 (16:9) Матриця: WOLED, відгук 0.03 мс"   (e-katalog, inline keys)

→ {"дисплей": "27\"", "частота оновлення": "240 Гц", ...} plus `flags` for the bare tokens
(IPS, 2560x1440) that carry no key.

Values are additionally read as numbers with a unit, normalised to a base unit so that
"3 кBт" and "3000 Вт" compare equal. Constraints (`want`) are therefore category-agnostic:

    {"потужність": [2000, 3000]}   numeric range in the value's own base unit
    {"напруга": 24}               exact number (±2%)
    {"форма": "синус"}            substring, checked in the value and in the whole line
    {"тип": ["AGM", "LiFePO4"]}   any of these substrings

A key is matched by normalised substring ("потужність" finds "номінальна потужність"), so the
user never has to know the aggregator's exact wording.
"""
from __future__ import annotations

import re
import unicodedata

# unit → (base unit, multiplier). Only arithmetic, no product knowledge.
UNITS: dict[str, tuple[str, float]] = {
    "вт": ("Вт", 1), "квт": ("Вт", 1000), "мвт": ("Вт", 0.001),
    "в·а": ("В·А", 1), "ва": ("В·А", 1), "кв·а": ("В·А", 1000),
    "в": ("В", 1), "кв": ("В", 1000), "мв": ("В", 0.001),
    "а": ("А", 1), "ма": ("А", 0.001),
    "а·год": ("А·год", 1), "а-год": ("А·год", 1), "ач": ("А·год", 1), "mah": ("А·год", 0.001),
    "вт·год": ("Вт·год", 1), "квт·год": ("Вт·год", 1000),
    "гц": ("Гц", 1), "кгц": ("Гц", 1000), "мгц": ("Гц", 1e6), "ггц": ("Гц", 1e9),
    "гб": ("ГБ", 1), "тб": ("ГБ", 1024), "мб": ("ГБ", 1 / 1024),
    "мм": ("мм", 1), "см": ("мм", 10), "м": ("мм", 1000),
    "кг": ("кг", 1), "г": ("кг", 0.001),
    "мс": ("мс", 1), "с": ("мс", 1000),
    "л": ("л", 1), "мл": ("л", 0.001),
    "°": ("°", 1), "%": ("%", 1),
    '"': ('"', 1), "″": ('"', 1), "дюйм": ('"', 1), "мп": ("Мп", 1),
}
UNIT_RE = "|".join(sorted((re.escape(u) for u in UNITS), key=len, reverse=True))
# a '-' right after a digit is a range separator ('220-230 В'), not a sign
NUM_RE = re.compile(r"((?<![\d,.])-?\d+(?:[.,]\d+)?)\s*(" + UNIT_RE + r")?", re.I)
# "Ключ: " — a key is 1–4 words, starts with a letter, ends at the colon.
KEY_RE = re.compile(r"(?:^|[;\u2022]\s*|\s)([A-Za-zА-Яа-яІЇЄҐіїєґ][\w'’\-()/ ]{1,45}?):\s*")
TOLERANCE = 0.02


def norm(s: str) -> str:
    """Casefold + strip accents/punctuation so 'Номінальна потужність' ≈ 'номинальная потужность'."""
    s = unicodedata.normalize("NFKD", str(s or "")).casefold()
    return re.sub(r"[^\w\s·]", " ", s).strip()


def number(value: str) -> tuple[float | None, str]:
    """'3 кBт' → (3000.0, 'Вт'); '26,5\"' → (26.5, '\"'); '2560x1440' → (None, '').

    A value may bundle several things ('26.5 ", 2560x1440 (16:9)'): each comma-separated part is
    tried in turn and the first scalar wins; shapes like 2560x1440 are never scalars.
    """
    whole = str(value or "").replace("\u00a0", " ").replace("B", "В")
    # split on separators, but NEVER on a decimal comma ('3,2 кВт' is one number)
    for part in re.split(r",(?!\d)|[()]", whole):
        v = part.replace("x", "х").strip()
        if not v or re.search(r"\d\s*х\s*\d", v):   # 2560x1440, 520 x 240 x 220 — a shape
            continue
        m = NUM_RE.search(v)
        if not m:
            continue
        n = float(m.group(1).replace(",", "."))
        unit = (m.group(2) or "").strip().casefold()
        base, mult = UNITS.get(unit, (m.group(2) or "", 1))
        return n * mult, base
    return None, ""


def _clean_key(key: str) -> str:
    """Drop leading tokens that belong to the previous value, not to this key:
    '280 Гц Відображення кольорів' → 'Відображення кольорів'."""
    words = key.split()
    while words and (re.fullmatch(r"-?\d+(?:[.,]\d+)?", words[0]) or words[0].casefold() in UNITS):
        words.pop(0)
    return " ".join(words).strip(" -–—,")


def numbers(value: str) -> list[tuple[float, str]]:
    """Every scalar in a value, so multi-mode specs match: '12/24 В' → [(12,'В'), (24,'В')].
    The unit of the last number applies to the earlier ones when they carry none."""
    whole = str(value or "").replace("\u00a0", " ").replace("B", "В")
    out: list[tuple[float, str]] = []
    for part in re.split(r",(?!\d)|[()]", whole):
        v = part.replace("x", "х").strip()
        if not v or re.search(r"\d\s*х\s*\d", v):
            continue
        found = [(float(m.group(1).replace(",", ".")), (m.group(2) or "").strip().casefold())
                 for m in NUM_RE.finditer(v) if m.group(1)]
        if not found:
            continue
        unit_of = {u for _, u in found if u}
        fallback = next(iter(unit_of)) if len(unit_of) == 1 else ""
        for n, u in found:
            base, mult = UNITS.get(u or fallback, (u or fallback, 1))
            out.append((n * mult, base))
        if out:
            break
    return out


def parse(line: str) -> dict:
    """Spec line → {"pairs": {key: value}, "flags": [bare tokens], "raw": line}.

    Segments are split on ';' first (hotline style), then each segment is scanned for inline
    'Ключ: значення' runs (e-katalog style); a segment with no key at all becomes a flag.
    """
    raw = re.sub(r"\s+", " ", str(line or "")).strip()
    if not raw:
        return {"pairs": {}, "flags": [], "raw": ""}
    pairs: dict[str, str] = {}
    flags: list[str] = []
    for segment in (seg.strip() for seg in raw.split(";")):
        if not segment:
            continue
        marks = [(m.start(1), m.end(0), _clean_key(m.group(1))) for m in KEY_RE.finditer(segment)]
        marks = [m for m in marks if m[2]]
        if not marks:
            flags += [t.strip() for t in segment.split(",") if t.strip()]
            continue
        head = segment[: marks[0][0]].strip(" ,")
        if head:
            flags += [t.strip() for t in head.split(",") if t.strip()]
        for i, (_, val_start, key) in enumerate(marks):
            end = marks[i + 1][0] if i + 1 < len(marks) else len(segment)
            value = segment[val_start:end].strip(" ,.")
            if key and value:
                pairs.setdefault(key, value)
    return {"pairs": pairs, "flags": flags, "raw": raw}


def find(spec: dict, key: str) -> tuple[str | None, str | None]:
    """Constraint key → (actual key, value) by normalised substring; longest key wins."""
    want = norm(key)
    hits = [(k, v) for k, v in spec["pairs"].items() if want in norm(k) or norm(k) in want]
    if not hits:
        return None, None
    k, v = max(hits, key=lambda kv: len(norm(kv[0])))
    return k, v


def check(spec: dict, key: str, want) -> tuple[bool | None, str]:
    """(True | False | None = not stated in this spec, explanation)."""
    actual_key, value = find(spec, key)
    hay = " ".join([spec["raw"], *spec["flags"]])
    if isinstance(want, (list, tuple)) and want and all(isinstance(x, (int, float)) for x in want):
        lo, hi = (float(want[0]), float(want[1])) if len(want) > 1 else (float(want[0]), float("inf"))
        if value is None:
            return None, f"{key}: не указано в спеке"
        nums = numbers(value)
        if not nums:
            return None, f"{key}: «{value}» не число"
        ok = any(lo * (1 - TOLERANCE) <= n <= hi * (1 + TOLERANCE) for n, _ in nums)   # '12/24 В' fits 24
        unit = nums[0][1]
        return ok, f"{actual_key}: {value}" + ("" if ok else f" вне [{lo:g}–{hi:g}]{' ' + unit if unit else ''}")
    if isinstance(want, (int, float)):
        if value is None:
            return None, f"{key}: не указано в спеке"
        nums = numbers(value)
        if not nums:
            return None, f"{key}: «{value}» не число"
        ok = any(abs(n - float(want)) <= abs(float(want)) * TOLERANCE for n, _ in nums)
        return ok, f"{actual_key}: {value}" + ("" if ok else f" ≠ {want:g}")
    words = [want] if isinstance(want, str) else list(want)
    for w in words:
        if norm(w) in norm(value or "") or norm(w) in norm(hay):
            return True, f"{actual_key or 'спека'}: содержит «{w}»"
    if value is None and not spec["pairs"]:
        return None, f"{key}: спека пустая"
    return False, f"{key}: нет «{'/'.join(words)}»" + (f" (есть {actual_key}: {value})" if value else "")


def match(line: str, want: dict | None, strict: bool = False) -> tuple[bool, list[str], list[str]]:
    """Check every constraint against one spec line.

    Returns (keep, reasons_failed, reasons_unknown). `strict=True` also drops rows whose spec
    does not state a constrained parameter — aggregator specs are patchy, so the default keeps
    them and reports what could not be verified.
    """
    if not want:
        return True, [], []
    spec = parse(line)
    failed, unknown = [], []
    for key, value in want.items():
        ok, why = check(spec, key, value)
        if ok is False:
            failed.append(why)
        elif ok is None:
            unknown.append(why)
    return (not failed and (not unknown or not strict)), failed, unknown


def facets(lines: list[str], top: int = 6, min_share: float = 0.15) -> list[dict]:
    """What parameters does this category actually have? Aggregate the candidates' own specs.

    → [{"key", "coverage", "unit", "range": [min, max], "values": [(value, count), ...]}]
    sorted by coverage. This is how the user picks constraints without knowing the category.
    """
    total = max(len(lines), 1)
    buckets: dict[str, dict] = {}
    for line in lines:
        for k, v in parse(line)["pairs"].items():
            b = buckets.setdefault(norm(k), {"key": k, "count": 0, "values": {}, "nums": [], "unit": ""})
            b["count"] += 1
            b["values"][v] = b["values"].get(v, 0) + 1
            n, unit = number(v)
            if n is not None:
                b["nums"].append(n)
                b["unit"] = b["unit"] or unit
    out = []
    for b in buckets.values():
        if b["count"] / total < min_share:
            continue
        vals = sorted(b["values"].items(), key=lambda kv: -kv[1])[:top]
        item = {"key": b["key"], "coverage": round(b["count"] / total, 2),
                "values": [{"value": v, "count": c} for v, c in vals]}
        if b["nums"]:
            item["unit"] = b["unit"]
            item["range"] = [min(b["nums"]), max(b["nums"])]
        out.append(item)
    return sorted(out, key=lambda x: (-x["coverage"], x["key"]))
