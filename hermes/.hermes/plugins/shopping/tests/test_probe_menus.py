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
from shopping.core.sources.epicentr import fetcher as epicentr  # noqa: E402
from shopping.core.sources.prom import fetcher as prom  # noqa: E402
from shopping.core.sources.rozetka import fetcher as rozetka  # noqa: E402
from shopping.core.sources.telemart import fetcher as telemart  # noqa: E402
from shopping.core.sources.citrus import fetcher as citrus  # noqa: E402
from shopping.core.sources.eldorado import fetcher as eldorado  # noqa: E402
from shopping.core.sources.brain import fetcher as brain  # noqa: E402
from shopping.core.sources.pn import fetcher as pn  # noqa: E402
from shopping.core.sources.ekatalog import fetcher as ekatalog  # noqa: E402
from shopping.core.sources.comfy import fetcher as comfy  # noqa: E402

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

    def test_citrus(self):
        meta = {}
        rows = citrus.parse_search(gz("citrus_search.html.gz"), meta)
        self.assertEqual(len(rows), 23)
        self.assertEqual(meta["total_est"], 78)
        self.assertEqual(rows[0]["price_uah"], 47099)
        self.assertEqual(rows[0]["notes"], "б/у")
        self.assertTrue(rows[0]["url"].startswith("https://citrus.ua/"))
        self.assertEqual(rows[0]["availability"], "є в наявності")
        self.assertEqual(meta["categories"][0], {"name": "Б/В iPhone", "count": 62})

    def test_eldorado_api(self):
        meta = {}
        rows = eldorado.parse_search(json.loads(gz("eldorado_search_api.json.gz")), meta)
        self.assertEqual(len(rows), 8)
        self.assertEqual(meta["total_est"], 8)
        self.assertEqual(rows[0]["price_uah"], 27999)
        self.assertEqual(rows[0]["availability"], "в наявності")
        self.assertEqual(rows[0]["url"], "https://eldorado.ua/uk/monitor-corsair-xeneon-27-qhd240-cm-9030002-pe-/p71468445/")
        self.assertIsNone(rows[1]["price_uah"])                 # "0.00" → no price
        self.assertEqual(rows[1]["availability"], "незабаром")

    def test_brain(self):
        meta = {}
        rows = brain.parse_search(gz("brain_search.html.gz"), meta)
        self.assertEqual(len(rows), 24)
        self.assertEqual(meta["total_est"], 2389)
        self.assertEqual(rows[0]["title"], "Скло захисне Armorstandart Pro Apple iPhone 17 / 16 Pro (ARM86210)")
        self.assertEqual(rows[0]["price_uah"], 299)
        self.assertEqual(rows[0]["price_note"], "было 369 ₴")
        self.assertEqual(rows[1]["price_uah"], 159)            # sibling card's price must not leak
        self.assertIn({"name": "Мобільні телефони", "count": 246}, meta["categories"])

    def test_pn(self):
        meta = {}
        rows = pn.parse_search(gz("pn_search.html.gz"), meta)
        self.assertEqual(len(rows), 13)
        self.assertEqual(meta["total_est"], 13)
        r = rows[0]
        self.assertEqual(r["title"], "Apple iPhone 16 Pro 256Gb Natural Titanium (MYNL3)")
        self.assertEqual((r["price_min_uah"], r["price_max_uah"], r["offers_count"]), (52099, 54272, 2))
        self.assertEqual(r["url"], "https://pn.com.ua/md/5789650/")

    def test_ekatalog_list_and_exact_redirect(self):
        meta = {}
        rows = ekatalog.parse_search(gz("ekatalog_search.html.gz"), meta)
        self.assertEqual(len(rows), 24)
        self.assertEqual(meta["total_est"], 47)
        r = rows[0]
        self.assertEqual(r["url"], "https://ek.ua/ua/ASUS-ROG-STRIX-OLED-XG27AQWMG.htm")
        self.assertEqual((r["price_min_uah"], r["price_max_uah"], r["offers_count"], r["rating_count"]), (29999, 37799, 12, 1))
        self.assertTrue(r["notes"].startswith("Екран: 26.5"))
        meta = {}
        rows = ekatalog.parse_search(gz("ekatalog_item_redirect.html.gz"), meta)   # exact query → product page
        self.assertEqual(meta["total_est"], 1)
        self.assertEqual(rows[0]["title"], "Смартфон Apple iPhone 16 Pro 256 ГБ")
        self.assertEqual(rows[0]["url"], "https://ek.ua/ua/ek-item.php?idg_=2760965")
        self.assertEqual(rows[0]["price_min_uah"], 40999)

    def test_comfy_initial_state(self):
        meta = {}
        rows = comfy.parse_search(gz("comfy_search_iphone.html.gz"), meta)
        self.assertEqual(len(rows), 50)
        self.assertEqual(meta["total_est"], 400)
        self.assertEqual(meta["categories"][0], {"name": "Смартфони", "count": 92})
        self.assertEqual(rows[0]["price_uah"], 699)
        self.assertEqual(rows[0]["price_note"], "было 1499 ₴")
        self.assertEqual((rows[0]["rating"], rows[0]["rating_count"]), (4.7, 17))
        self.assertEqual(rows[0]["seller"], "Comfy")
        self.assertTrue(rows[0]["url"].startswith("https://comfy.ua/ua/"))
        self.assertEqual(comfy.parse_search("<html>no state</html>", {}), [])

    def test_chromium_dom_errors(self):
        from shopping.core import http
        with mock.patch.object(http, "chromium_path", return_value=None):
            with self.assertRaises(http.FetchError):
                http.chromium_dom("https://example.com")
        with mock.patch.object(http, "chromium_path", return_value="/bin/true"):
            with self.assertRaises(http.FetchError):        # empty DOM
                http.chromium_dom("https://example.com", timeout=5)

    def test_rozetka_search_total_and_seller(self):
        meta = {}
        ids = rozetka.parse_search(json.loads(gz("rozetka_search_api.json.gz")), meta)
        self.assertEqual(meta["total_est"], 1119)
        self.assertEqual(len(ids), 60)
        self.assertEqual(meta["categories"][0], {"name": "Інвертори", "count": 107})
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


class Registry(Isolated):
    def test_every_folder_is_a_source_and_config_is_valid(self):
        from shopping.core import sources
        keys = [s.key for s in sources.all_sources()]
        self.assertEqual(len(keys), 14)
        self.assertEqual(keys[0], "hotline")                       # aggregators first
        self.assertEqual(sources.validate(), [])
        self.assertEqual(sorted(s.key for s in sources.scripted()),
                         ["allo", "brain", "citrus", "comfy", "ekatalog", "eldorado", "epicentr", "foxtrot", "hotline", "moyo", "pn", "prom", "rozetka", "telemart"])
        self.assertTrue(sources.get("hotline").filters)
        self.assertIn("{q}", sources.get("comfy").search)
        self.assertEqual(sources.get("comfy").fetch, "chromium")
        self.assertTrue(all(s.scripted for s in sources.all_sources()))     # policy: only sites that work stay
        self.assertEqual(sources.get("prom").search_url("a b"), "https://prom.ua/ua/search?search_term=a+b")

    def test_user_dir_source_is_discovered(self):
        from shopping.core import sources
        d = Path(os.environ["SHOPPING_HOME"]) / ".config" / "sources" / "olx"
        d.mkdir(parents=True)
        (d / "source.yaml").write_text("key: olx\ntitle: OLX\ngroup: marketplace\nfetch: browser\nsearch: https://www.olx.ua/uk/list/q-{q}/\n")
        sources.reload()
        try:
            self.assertIn("olx", [s.key for s in sources.all_sources()])
            self.assertEqual(sources.get("olx").title, "OLX")
        finally:
            sources.reload()

    def test_shop_sources_document(self):
        doc = core.get_sources()["sources"]
        self.assertEqual(set(doc), {"geo", "reviews", "aggregators", "marketplaces", "hotline_filters"})
        self.assertEqual(doc["marketplaces"]["rozetka"]["fetch"], "script")
        self.assertIn("web_search_queries", doc["reviews"])


class Probe(Isolated):
    def test_sites_follow_catalogue_order_and_flags(self):
        s = probe_mod.sites(exclude=["comfy"])
        keys = [x["site"] for x in s]
        self.assertEqual(keys[0], "hotline")
        self.assertNotIn("comfy", keys)
        self.assertTrue(next(x for x in s if x["site"] == "epicentr")["scripted"])

    def test_probe_parallel_and_error_isolated(self):
        def fake_search(query, meta=None, **kw):
            if meta is not None:
                meta["total_est"] = 42
                meta["categories"] = [{"name": "чохли", "count": 30}, {"name": "телефони", "count": 12}, {"name": "x", "count": None}, {"name": "чохли", "count": 30}]
            return [{"title": f"{query} x", "price_uah": 10}] * 5

        class Mod:
            search = staticmethod(fake_search)

        class Dead:
            @staticmethod
            def search(query, meta=None, **kw):
                raise RuntimeError("boom")

        class Src:
            def __init__(self, m): self._m = m
            def module(self): return self._m

        with mock.patch.object(probe_mod.sources, "get", side_effect=lambda site: Src(Dead if site == "moyo" else Mod)):
            r = probe_mod.probe("монитор", only=["hotline", "moyo", "prom"])
        by = {x["site"]: x for x in r["sites"]}
        self.assertEqual(by["hotline"]["hits"], 5)
        self.assertEqual(by["hotline"]["total_est"], 42)
        self.assertEqual(len(by["hotline"]["sample"]), 3)
        self.assertEqual([c["name"] for c in by["hotline"]["categories"]], ["чохли", "телефони", "x"])
        self.assertIn("boom", by["moyo"]["error"])
        self.assertEqual(by["moyo"]["status"], "error")
        self.assertEqual(r["with_hits"], ["hotline", "prom"])
        self.assertEqual(by["rozetka"]["status"], "excluded")     # not in `only`
        self.assertEqual(len(r["sites"]), 14)

    def test_probe_empty_query(self):
        self.assertFalse(probe_mod.probe("  ")["success"])


class Menus(Isolated):
    def test_sources_menu_order_and_labels(self):
        pr = {"sites": [{"site": "hotline", "status": "hits", "probed": True, "hits": 25, "total_est": None},
                        {"site": "brain", "status": "hits", "probed": True, "hits": 24, "total_est": 2389,
                         "categories": [{"name": "Чохли для мобільних телефонів", "count": 1400}, {"name": "Захисне скло", "count": 543},
                                        {"name": "Мобільні телефони", "count": 246}, {"name": "Планшети", "count": 1}]},
                        {"site": "rozetka", "status": "hits", "probed": True, "hits": 3, "total_est": 719},
                        {"site": "moyo", "status": "zero", "probed": True, "hits": 0},
                        {"site": "allo", "status": "error", "probed": True, "hits": 0, "error": "blocked (403)"},
                        {"site": "prom", "status": "excluded", "probed": False},
                        {"site": "epicentr", "status": "no_script", "probed": False}]}
        m = menus.sources_menu(pr)
        labels = [i["label"] for i in m["items"]]
        self.assertEqual(labels[0], "Brain (1 400 чохли для мобільних телефонів · 543 захисне скло · 246 мобільні телефони · +1)")
        self.assertEqual(labels[1:3], ["Rozetka (719+)", "Hotline (25)"])      # most hits first
        self.assertIn("Алло (ошибка зонда)", labels)
        self.assertIn("Prom.ua (исключён из зонда)", labels)
        self.assertIn("Епіцентр (нет скрипта — только браузер)", labels)
        self.assertEqual(labels[-1], "MOYO (0 — не найдено)")                  # zeros last, still visible
        self.assertEqual(len(labels), 14)                                      # every source is listed
        self.assertTrue(m["multi"])
        self.assertTrue(all("," not in lab for lab in labels))

    def test_sources_menu_without_probe_keeps_catalogue_order(self):
        m = menus.sources_menu(None, exclude=["comfy"])
        self.assertEqual(m["items"][0]["value"], "hotline")
        self.assertNotIn("comfy", [i["value"] for i in m["items"]])
        self.assertNotIn("(браузер)", " ".join(i["label"] for i in m["items"]))
        self.assertIn("Прайс Навигатор (pn.com.ua)", [i["label"] for i in m["items"]])

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
        self.assertTrue(labels[0].startswith("все 14"))
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
