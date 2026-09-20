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
    def test_units_are_kept_as_written(self):
        self.assertEqual(spec.numbers("3 кBт"), [{"n": 3.0, "unit": "кBт"}])
        self.assertEqual(spec.numbers("3,2 кBт"), [{"n": 3.2, "unit": "кBт"}])
        self.assertEqual(spec.numbers("100 А·год"), [{"n": 100.0, "unit": "А·год"}])
        self.assertEqual(spec.numbers("5 Нм"), [{"n": 5.0, "unit": "Нм"}])          # unknown unit: no special case
        self.assertEqual(spec.numbers("800 люмен"), [{"n": 800.0, "unit": "люмен"}])

    def test_shapes_and_multi_values(self):
        self.assertEqual(spec.numbers("2560x1440"), [])
        self.assertEqual(spec.numbers('26.5 ", 2560x1440 (16:9)')[0]["n"], 26.5)      # first part wins
        self.assertEqual([x["n"] for x in spec.numbers("12/24 В")], [12.0, 24.0])
        self.assertEqual([x["unit"] for x in spec.numbers("12/24 В")], ["В", "В"])    # borrowed unit
        self.assertEqual([x["n"] for x in spec.numbers("220-230 B")], [220.0, 230.0])  # range, not a sign


class Evaluate(unittest.TestCase):
    """Criteria are authored by the model: alternative unit spellings live in `any_of`."""

    POWER = {"key": "потужність", "label": "2–3 кВт",
             "any_of": [{"min": 2000, "max": 3000, "unit": "Вт"}, {"min": 2, "max": 3, "unit": "кBт"}]}

    def test_alternative_unit_spellings_in_any_of(self):
        self.assertTrue(spec.evaluate(HOTLINE_HYBRID, [self.POWER])[0])      # matches the "3 кBт" rule
        self.assertTrue(spec.evaluate(HOTLINE_INVERTER, [self.POWER])[0])    # matches the "2000 Вт" rule
        ok, failed, _ = spec.evaluate("інвертор; потужність: 4 кBт", [self.POWER])
        self.assertFalse(ok)
        self.assertIn("2–3 кВт", failed[0])

    def test_unit_must_match_when_given(self):
        crit = [{"key": "потужність", "any_of": [{"min": 2, "max": 3, "unit": "кBт"}]}]
        self.assertFalse(spec.evaluate(HOTLINE_INVERTER, crit)[0])           # 2000 Вт is not 2–3 кBт
        loose = [{"key": "потужність", "any_of": [{"min": 2, "max": 3}]}]     # no unit = any unit
        self.assertTrue(spec.evaluate(HOTLINE_HYBRID, loose)[0])

    def test_open_range_and_eq(self):
        self.assertTrue(spec.evaluate(HOTLINE_MONITOR, [{"key": "частота", "any_of": [{"min": 100}]}])[0])
        self.assertFalse(spec.evaluate(HOTLINE_MONITOR, [{"key": "частота", "any_of": [{"min": 500}]}])[0])
        self.assertTrue(spec.evaluate(HOTLINE_CHARGER, [{"key": "робоча напруга", "any_of": [{"eq": 24, "unit": "B"}]}])[0])
        self.assertFalse(spec.evaluate(HOTLINE_CHARGER, [{"key": "робоча напруга", "any_of": [{"eq": 48, "unit": "B"}]}])[0])

    def test_multi_mode_value_matches_either(self):
        line = "Перетворювач (інвертор) DC-AC; вхідна напруга: 12/24 В; потужність: 600 Вт"
        self.assertTrue(spec.evaluate(line, [{"key": "вхідна напруга", "any_of": [{"eq": 24, "unit": "В"}]}])[0])
        self.assertFalse(spec.evaluate(line, [{"key": "вхідна напруга", "any_of": [{"eq": 48, "unit": "В"}]}])[0])

    def test_contains_looks_at_value_and_whole_line(self):
        self.assertTrue(spec.evaluate(HOTLINE_HYBRID, [{"key": "форма", "contains": ["синус"]}])[0])
        self.assertTrue(spec.evaluate(HOTLINE_MONITOR, [{"key": "панель", "contains": ["OLED", "IPS"]}])[0])   # from flags
        self.assertFalse(spec.evaluate(HOTLINE_INVERTER, [{"key": "форма", "contains": ["синус"]}])[0])

    def test_loose_key_matching(self):
        self.assertTrue(spec.evaluate(HOTLINE_CHARGER, [{"key": "струму заряду", "any_of": [{"min": 20, "max": 40}]}])[0])
        self.assertTrue(spec.evaluate(HOTLINE_PHONE, [{"key": "пам'ять", "any_of": [{"min": 256}]}])[0])

    def test_unknown_parameter_is_kept_unless_strict(self):
        crit = [{"key": "вага", "any_of": [{"min": 1, "max": 10}]}]
        ok, failed, unknown = spec.evaluate(HOTLINE_INVERTER, crit)
        self.assertTrue(ok)
        self.assertEqual(failed, [])
        self.assertIn("не указано", unknown[0])
        self.assertFalse(spec.evaluate(HOTLINE_INVERTER, crit, strict=True)[0])

    def test_no_criteria_keeps_everything(self):
        self.assertTrue(spec.evaluate("", None)[0])
        self.assertTrue(spec.evaluate("", [])[0])

    def test_describe_for_the_user(self):
        lines = spec.describe([self.POWER, {"key": "форма", "contains": ["синус"]},
                               {"key": "вага", "any_of": [{"max": 20, "unit": "кг"}], "required": False}])
        self.assertEqual(lines[0], "потужність: 2–3 кВт")
        self.assertEqual(lines[1], "форма: синус")
        self.assertIn("(желательно)", lines[2])


class Observe(unittest.TestCase):
    def test_observe_describes_the_result_set(self):
        lines = [HOTLINE_INVERTER, HOTLINE_HYBRID,
                 "Перетворювач (інвертор) DC-AC; вхідна напруга: 12 В; потужність: 1000 Вт",
                 "Перетворювач (інвертор) DC-AC; вхідна напруга: 24 В; потужність: 3000 Вт"]
        o = {x["key"]: x for x in spec.observe(lines, min_share=0.2)}
        self.assertIn("потужність", o)
        units = {u["unit"]: u for u in o["потужність"]["units"]}
        self.assertEqual((units["Вт"]["min"], units["Вт"]["max"]), (1000.0, 3000.0))   # per RAW unit
        self.assertEqual(o["вхідна напруга"]["coverage"], 0.75)
        self.assertEqual(o["вхідна напруга"]["values"][0]["value"], "24 В")   # most common first

    def test_observe_separates_unit_spellings(self):
        o = {x["key"]: x for x in spec.observe(["інвертор; потужність: 2000 Вт",
                                                "інвертор; потужність: 3 кBт"], min_share=0.1)}
        self.assertEqual({u["unit"] for u in o["потужність"]["units"]}, {"Вт", "кBт"})

    def test_rare_keys_are_dropped(self):
        lines = [HOTLINE_INVERTER] * 19 + [HOTLINE_MONITOR]
        self.assertNotIn("дисплей", {x["key"] for x in spec.observe(lines)})


class CandidatesCriteriaFilter(unittest.TestCase):
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

    def test_criteria_filter_and_explain(self):
        r = self.run_discover(criteria=[{"key": "форма", "contains": ["синус"]}])
        self.assertEqual([c["model"] for c in r["candidates"]], ["B hybrid", "C no spec"])
        self.assertEqual(r["dropped_count"], 1)
        self.assertEqual(r["dropped_by_spec"][0]["model"], "A 2000")
        self.assertIn("unverified", r["candidates"][1])      # C has no spec → kept, flagged

    def test_strict_drops_unverifiable(self):
        r = self.run_discover(criteria=[{"key": "форма", "contains": ["синус"]}], strict=True)
        self.assertEqual([c["model"] for c in r["candidates"]], ["B hybrid"])

    def test_observed_always_returned(self):
        keys = {f["key"] for f in self.run_discover()["observed"]}
        self.assertIn("потужність", keys)

    def test_all_dropped_reports_hint_and_facets(self):
        # strict: the card with no spec cannot be verified either → nothing survives
        r = self.run_discover(criteria=[{"key": "потужність", "any_of": [{"min": 9000}]}], strict=True)
        self.assertFalse(r["success"])
        self.assertIn("loosen", r["error"])
        self.assertTrue(r["observed"])


if __name__ == "__main__":
    unittest.main()
