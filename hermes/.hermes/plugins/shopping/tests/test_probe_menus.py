"""Tests: new fetchers (epicentr/prom/telemart), probe service, menus (pure) and the clarify UI adapter."""
from __future__ import annotations

import gzip
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
os.environ["SHOPPING_HOME"] = tempfile.mkdtemp(prefix="shoptest-")

from shopping import core, ui  # noqa: E402
from shopping.core import menus  # noqa: E402
from shopping.core import probe as probe_mod  # noqa: E402
from shopping.core.fetchers import epicentr, prom, rozetka, telemart  # noqa: E402

FIX = Path(__file__).parent / "fixtures"


def gz(name: str) -> str:
    return gzip.open(FIX / name, "rt", encoding="utf-8").read()


class NewParsers(unittest.TestCase):
    def test_epicentr(self):
        meta = {}
        rows = epicentr.parse_search(gz("epicentr_search.html.gz"), meta)
        self.assertEqual(len(rows), 40)
        self.assertEqual(meta["pages"], 10)
        self.assertEqual(meta["total_est"], 400)
        r = rows[0]
        self.assertEqual(r["price_uah"], 4799)
        self.assertEqual(r["rating_count"], 20)
        self.assertEqual(r["seller"], "Епіцентр")
        self.assertIn("продавец маркетплейса", {x["seller"] for x in rows})
        self.assertTrue(all(x["url"].startswith("https://epicentrk.ua/") for x in rows))

    def test_prom(self):
        meta = {}
        rows = prom.parse_search(gz("prom_search.html.gz"), meta)
        self.assertEqual(len(rows), 10)
        self.assertEqual(meta["total_est"], 3000)
        r = rows[0]
        self.assertEqual(r["price_uah"], 2460)
        self.assertEqual(r["seller"], "YouShine")
        self.assertTrue(r["installment"])
        self.assertIn("надійність продавця", r["notes"])
        self.assertEqual(rows[1]["price_uah"], 11008)  # "11008.01" must not become 1100801

    def test_telemart(self):
        rows = telemart.parse_search(gz("telemart_search.html.gz"))
        self.assertEqual(len(rows), 10)
        self.assertEqual(rows[0]["availability"], "немає в наявності")
        self.assertIsNone(rows[0]["price_uah"])
        self.assertEqual(rows[1]["price_uah"], 89982)
        self.assertEqual(rows[1]["price_note"], "было 109400 ₴")
        self.assertEqual(rows[1]["installment_note"], "від 14997 ₴/міс")

    def test_rozetka_search_total_and_seller(self):
        meta = {}
        ids = rozetka.parse_search(json.loads(gz("rozetka_search_api.json.gz")), meta)
        self.assertEqual(meta["total_est"], 1119)
        self.assertEqual(len(ids), 60)
        det = rozetka.parse_details(json.loads(gz("rozetka_details_api.json.gz")))
        self.assertIn(615896048, det)
        self.assertEqual(rozetka._seller({"seller": "RENEGAT"}, ""), "RENEGAT (маркетплейс)")
        self.assertEqual(rozetka._seller({}, "https://hard.rozetka.com.ua/msi-x/p1/"), "Rozetka")


class Isolated(unittest.TestCase):
    """Other suites pop SHOPPING_HOME in tearDown — pin our own temp home per test."""
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        os.environ["SHOPPING_HOME"] = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()
        os.environ.pop("SHOPPING_HOME", None)


class Probe(Isolated):
    def test_sites_follow_catalogue_order_and_flags(self):
        s = probe_mod.sites(exclude=["comfy"])
        keys = [x["site"] for x in s]
        self.assertEqual(keys[0], "hotline")
        self.assertNotIn("comfy", keys)
        self.assertTrue(next(x for x in s if x["site"] == "epicentr")["scripted"])
        self.assertFalse(next(x for x in s if x["site"] == "brain")["scripted"])

    def test_probe_parallel_and_error_isolated(self):
        def fake_search(query, meta=None, **kw):
            if meta is not None:
                meta["total_est"] = 42
            return [{"title": f"{query} x", "price_uah": 10}] * 5

        class Mod:
            search = staticmethod(fake_search)

        class Dead:
            @staticmethod
            def search(query, meta=None, **kw):
                raise RuntimeError("boom")

        with mock.patch.object(probe_mod.fetchers, "get", side_effect=lambda site: Dead if site == "moyo" else Mod):
            r = probe_mod.probe("монитор", only=["hotline", "moyo", "prom"])
        by = {x["site"]: x for x in r["sites"]}
        self.assertEqual(by["hotline"]["hits"], 5)
        self.assertEqual(by["hotline"]["total_est"], 42)
        self.assertEqual(len(by["hotline"]["sample"]), 3)
        self.assertIn("boom", by["moyo"]["error"])
        self.assertEqual(r["with_hits"], ["hotline", "prom"])

    def test_probe_empty_query(self):
        self.assertFalse(probe_mod.probe("  ")["success"])


class Menus(Isolated):
    def test_sources_menu_order_and_labels(self):
        pr = {"sites": [{"site": "hotline", "probed": True, "hits": 25, "total_est": None},
                        {"site": "rozetka", "probed": True, "hits": 3, "total_est": 719},
                        {"site": "moyo", "probed": True, "hits": 0},
                        {"site": "allo", "probed": True, "hits": 0, "error": "blocked (403)"}]}
        m = menus.sources_menu(pr)
        labels = [i["label"] for i in m["items"]]
        self.assertEqual(labels[:2], ["Rozetka (719+)", "Hotline (25)"])      # most hits first
        self.assertIn("Алло (ошибка)", labels)
        self.assertIn("Comfy (без зонда)", labels)
        self.assertNotIn("MOYO (0)", labels)                                   # zero-hit sites dropped…
        self.assertIn("0 находок: MOYO", m["question"])                        # …and named
        self.assertTrue(m["multi"])
        self.assertTrue(all("," not in lab for lab in labels))

    def test_sources_menu_without_probe_keeps_catalogue_order(self):
        m = menus.sources_menu(None, exclude=["comfy"])
        self.assertEqual(m["items"][0]["value"], "hotline")
        self.assertNotIn("comfy", [i["value"] for i in m["items"]])
        self.assertIn("E-Katalog (браузер)", [i["label"] for i in m["items"]])

    def test_parse_answer_multi_string_and_free_text(self):
        menu = {"multi": True, "items": [{"value": "hotline", "label": "Hotline (25)"}, {"value": "rozetka", "label": "Rozetka (719+)"}]}
        r = menus.parse_answer(menu, "Hotline (25), Rozetka (719+), olx тоже")
        self.assertEqual(r["values"], ["hotline", "rozetka"])
        self.assertEqual(r["free_text"], "olx тоже")
        self.assertEqual(menus.parse_answer(menu, ""), {"values": [], "free_text": None})
        single = {"multi": False, "items": menu["items"]}
        self.assertEqual(menus.parse_answer(single, "Hotline (25)")["values"], ["hotline"])
        self.assertEqual(menus.parse_answer(single, "что-то, с запятой")["free_text"], "что-то, с запятой")

    def test_probe_menu_lists_every_scripted_site_by_name(self):
        m = menus.probe_menu()
        labels = [i["label"] for i in m["items"]]
        self.assertTrue(labels[0].startswith("все 8"))
        self.assertIn("Епіцентр", labels)
        self.assertEqual(m["items"][-1]["value"], menus.PROBE_SKIP)
        self.assertTrue(m["multi"])
        self.assertEqual(menus.probe_selection([]), {"probe": False, "only": None})
        self.assertEqual(menus.probe_selection([menus.PROBE_ALL, "hotline"]), {"probe": True, "only": None})
        self.assertEqual(menus.probe_selection(["hotline", "prom"]), {"probe": True, "only": ["hotline", "prom"]})
        self.assertEqual(menus.probe_selection(["hotline", menus.PROBE_SKIP])["probe"], False)

    def test_topics_and_sessions_menus(self):
        core.create_topic("monitor")
        core.create_session("monitor", "монитор 27", purpose="работа")
        t = menus.topics_menu()
        self.assertEqual(t["items"][-1]["value"], menus.NEW_TOPIC)
        self.assertEqual(t["items"][0]["value"], "monitor")
        s = menus.sessions_menu("monitor")
        self.assertEqual(s["items"][-1]["value"], menus.NEW_SESSION)
        self.assertIn("монитор 27", s["items"][0]["label"])


class UiAdapter(unittest.TestCase):
    def test_multi_passes_full_list_and_parses(self):
        seen = {}

        def cb(question, choices, multi_select=False):
            seen.update(question=question, choices=choices, multi=multi_select)
            return f"{choices[0]}, {choices[4]}"

        menu = {"question": "Q", "multi": True, "items": [{"value": str(i), "label": f"i{i}"} for i in range(12)]}
        r = ui.ask(menu, callback=cb)
        self.assertEqual(len(seen["choices"]), 12)         # no 4-choice cap
        self.assertTrue(seen["multi"])
        self.assertEqual(r["values"], ["0", "4"])

    def test_single_and_old_callback_signature(self):
        def cb(question, choices):                          # no multi_select kwarg
            return choices[1]
        menu = {"question": "Q", "multi": False, "items": [{"value": "a", "label": "A"}, {"value": "b", "label": "B"}]}
        self.assertEqual(ui.ask(menu, callback=cb)["values"], ["b"])

    def test_no_callback_means_no_ui(self):
        with mock.patch.object(ui, "resolve_clarify_callback", return_value=None):
            with self.assertRaises(ui.NoUI):
                ui.ask({"question": "Q", "multi": False, "items": [{"value": "a", "label": "A"}]})


if __name__ == "__main__":
    unittest.main()
