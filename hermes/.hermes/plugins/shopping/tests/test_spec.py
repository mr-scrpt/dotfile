"""Tests: category-agnostic spec parsing / matching / facets (core.spec) and the want filter in shop_candidates."""
from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from shopping.core import spec  # noqa: E402

HOTLINE_INVERTER = ("Перетворювач (інвертор) DC-AC; вхідне підключення: Акумулятор автомобіля (клеми); "
                    "вхідна напруга: 24 В; потужність: 2000 Вт")
HOTLINE_HYBRID = ("Гібридний сонячний інвертор (hybrid); номінальна потужність: 3 кBт; кількість фаз: однофазний; "
                  "форма вихідного сигналу: чиста синусоїда; напруга акумулятора (АКБ): 24 B")
HOTLINE_MONITOR = ('дисплей: 26,5"; QD-OLED; 2560x1440; 16:9; частота оновлення: 240 Гц; '
                   "максимальна яскравість: 1000 кд/м²")
EKATALOG_MONITOR = ('Екран: 26.5 ", 2560x1440 (16:9) Матриця: WOLED, відгук 0.03 мс, 280 Гц '
                    "Відображення кольорів: 1.07 млрд")
HOTLINE_CHARGER = ("Зарядний пристрій LiFePo4 акумулятора; робоча напруга: 24 B; "
                   "максимальна сила струму заряду при 12 В: 25 А")
HOTLINE_PHONE = "смартфон; екран: 6.3\"; пам'ять: 256 ГБ; основна камера: 48 Мп; акумулятор: 3582 мА·год"


class ParseLine(unittest.TestCase):
    def test_hotline_semicolon_style(self):
        p = spec.parse(HOTLINE_INVERTER)
        self.assertEqual(p["pairs"]["потужність"], "2000 Вт")
        self.assertEqual(p["pairs"]["вхідна напруга"], "24 В")
        self.assertIn("Перетворювач (інвертор) DC-AC", p["flags"])

    def test_key_with_parentheses(self):
        self.assertEqual(spec.parse(HOTLINE_HYBRID)["pairs"]["напруга акумулятора (АКБ)"], "24 B")

    def test_ekatalog_inline_style_and_key_cleanup(self):
        p = spec.parse(EKATALOG_MONITOR)
        self.assertEqual(p["pairs"]["Матриця"], "WOLED, відгук 0.03 мс, 280")
        self.assertIn("Відображення кольорів", p["pairs"])        # not "280 Гц Відображення кольорів"
        self.assertNotIn("Гц Відображення кольорів", p["pairs"])

    def test_bare_tokens_become_flags(self):
        p = spec.parse(HOTLINE_MONITOR)
        self.assertEqual(p["pairs"]["частота оновлення"], "240 Гц")
        self.assertIn("QD-OLED", p["flags"])
        self.assertIn("2560x1440", p["flags"])

    def test_empty(self):
        self.assertEqual(spec.parse("")["pairs"], {})


class Numbers(unittest.TestCase):
    def test_units_normalise_to_a_base(self):
        self.assertEqual(spec.number("3 кBт"), (3000.0, "Вт"))
        self.assertEqual(spec.number("3,2 кBт"), (3200.0, "Вт"))
        self.assertEqual(spec.number("100 А·год"), (100.0, "А·год"))
        self.assertEqual(spec.number("256 ГБ")[0], 256.0)

    def test_shapes_and_multi_values(self):
        self.assertEqual(spec.number("2560x1440"), (None, ""))
        self.assertEqual(spec.number('26.5 ", 2560x1440 (16:9)')[0], 26.5)      # first scalar wins
        self.assertEqual([n for n, _ in spec.numbers("12/24 В")], [12.0, 24.0])
        self.assertEqual([n for n, _ in spec.numbers("220-230 B")], [220.0, 230.0])   # range, not a sign


class Match(unittest.TestCase):
    def test_numeric_range_across_units(self):
        ok, failed, unknown = spec.match(HOTLINE_HYBRID, {"потужність": [2000, 3000]})
        self.assertTrue(ok, (failed, unknown))                     # 3 кВт == 3000 Вт
        ok, failed, _ = spec.match(HOTLINE_INVERTER, {"потужність": [2500, 3000]})
        self.assertFalse(ok)
        self.assertIn("вне", failed[0])

    def test_open_ended_range_and_exact_number(self):
        self.assertTrue(spec.match(HOTLINE_MONITOR, {"частота": [100]})[0])
        self.assertFalse(spec.match(HOTLINE_MONITOR, {"частота": [500]})[0])
        self.assertTrue(spec.match(HOTLINE_CHARGER, {"робоча напруга": 24})[0])
        self.assertFalse(spec.match(HOTLINE_CHARGER, {"робоча напруга": 48})[0])

    def test_multi_mode_value_matches_either(self):
        line = "Перетворювач (інвертор) DC-AC; вхідна напруга: 12/24 В; потужність: 600 Вт"
        self.assertTrue(spec.match(line, {"вхідна напруга": 24})[0])
        self.assertFalse(spec.match(line, {"вхідна напруга": 48})[0])

    def test_substring_constraints_look_at_the_whole_line(self):
        self.assertTrue(spec.match(HOTLINE_HYBRID, {"форма": "синус"})[0])
        self.assertTrue(spec.match(HOTLINE_MONITOR, {"панель": ["OLED", "IPS"]})[0])   # from flags
        self.assertFalse(spec.match(HOTLINE_INVERTER, {"форма": "синус"})[0])

    def test_loose_key_matching(self):
        self.assertTrue(spec.match(HOTLINE_CHARGER, {"струму заряду": [20, 40]})[0])
        self.assertTrue(spec.match(HOTLINE_PHONE, {"пам'ять": [256]})[0])

    def test_unknown_parameter_is_kept_unless_strict(self):
        ok, failed, unknown = spec.match(HOTLINE_INVERTER, {"вага": [1, 10]})
        self.assertTrue(ok)
        self.assertEqual(failed, [])
        self.assertIn("не указано", unknown[0])
        self.assertFalse(spec.match(HOTLINE_INVERTER, {"вага": [1, 10]}, strict=True)[0])

    def test_no_constraints_keeps_everything(self):
        self.assertTrue(spec.match("", None)[0])
        self.assertTrue(spec.match("", {})[0])


class Facets(unittest.TestCase):
    def test_facets_describe_the_category(self):
        lines = [HOTLINE_INVERTER, HOTLINE_HYBRID,
                 "Перетворювач (інвертор) DC-AC; вхідна напруга: 12 В; потужність: 1000 Вт",
                 "Перетворювач (інвертор) DC-AC; вхідна напруга: 24 В; потужність: 3000 Вт"]
        f = {x["key"]: x for x in spec.facets(lines, min_share=0.2)}
        self.assertIn("потужність", f)
        self.assertEqual(f["потужність"]["unit"], "Вт")
        self.assertEqual(f["потужність"]["range"], [1000.0, 3000.0])
        self.assertEqual(f["вхідна напруга"]["coverage"], 0.75)
        self.assertEqual(f["вхідна напруга"]["values"][0]["value"], "24 В")   # most common first

    def test_rare_keys_are_dropped(self):
        lines = [HOTLINE_INVERTER] * 9 + [HOTLINE_MONITOR]
        self.assertNotIn("дисплей", {x["key"] for x in spec.facets(lines)})


class CandidatesWantFilter(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = mock.patch.dict(os.environ, {"SHOPPING_HOME": self.tmp.name})
        self.env.start()
        from shopping import core
        core.create_topic("t")
        self.sid = core.create_session("t", "інвертор", "резерв")["session"]["id"]

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def rows(self):
        return [{"group": "aggregator", "source": "hotline", "model": "A 2000", "title": "A 2000",
                 "url": "https://h/a", "offers_count": 9, "notes": HOTLINE_INVERTER},
                {"group": "aggregator", "source": "hotline", "model": "B hybrid", "title": "B hybrid",
                 "url": "https://h/b", "offers_count": 5, "notes": HOTLINE_HYBRID},
                {"group": "aggregator", "source": "hotline", "model": "C no spec", "title": "C no spec",
                 "url": "https://h/c", "offers_count": 3, "notes": ""}]

    def run_discover(self, **kw):
        from shopping import core
        from shopping.core import candidates
        with mock.patch.object(candidates, "_search_all", return_value=(self.rows(), [], [])):
            return core.find_candidates("t", self.sid, "інвертор 24V", **kw)

    def test_want_filters_and_explains(self):
        r = self.run_discover(want={"форма": "синус"})
        self.assertEqual([c["model"] for c in r["candidates"]], ["B hybrid", "C no spec"])
        self.assertEqual(r["dropped_count"], 1)
        self.assertEqual(r["dropped_by_spec"][0]["model"], "A 2000")
        self.assertIn("unverified", r["candidates"][1])      # C has no spec → kept, flagged

    def test_strict_drops_unverifiable(self):
        r = self.run_discover(want={"форма": "синус"}, strict=True)
        self.assertEqual([c["model"] for c in r["candidates"]], ["B hybrid"])

    def test_facets_always_returned(self):
        keys = {f["key"] for f in self.run_discover()["facets"]}
        self.assertIn("потужність", keys)

    def test_all_dropped_reports_hint_and_facets(self):
        # strict: the card with no spec cannot be verified either → nothing survives
        r = self.run_discover(want={"потужність": [9000, 10000]}, strict=True)
        self.assertFalse(r["success"])
        self.assertIn("loosen", r["error"])
        self.assertTrue(r["facets"])


if __name__ == "__main__":
    unittest.main()
