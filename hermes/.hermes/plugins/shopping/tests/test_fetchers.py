"""Fetcher tests: pure parsers on saved fixtures + fetch service with the network mocked out."""
from __future__ import annotations

import gzip
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

PLUGINS_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PLUGINS_DIR))
FX = Path(__file__).resolve().parent / "fixtures"

from shopping import core  # noqa: E402
from shopping.core import fetch as fetch_svc  # noqa: E402
from shopping.core.sources.allo import fetcher as allo  # noqa: E402
from shopping.core.sources.foxtrot import fetcher as foxtrot  # noqa: E402
from shopping.core.sources.hotline import fetcher as hotline  # noqa: E402
from shopping.core.sources.moyo import fetcher as moyo  # noqa: E402
from shopping.core.sources.rozetka import fetcher as rozetka  # noqa: E402
from shopping.core.http import Response, nuxt_state  # noqa: E402


def gz(name: str) -> str:
    return gzip.open(FX / name, "rt", encoding="utf-8").read()


def js(name: str):
    return json.loads((FX / name).read_text(encoding="utf-8"), strict=False)


class HotlineParsers(unittest.TestCase):
    def test_catalog_cards_filters_and_spec(self):
        c = hotline.parse_catalog(gz("hotline_catalog.html.gz"))
        self.assertEqual(len(c["cards"]), 48)
        self.assertEqual(c["selected"], ['27-28"', "OLED", "QD-OLED"])
        self.assertEqual(c["filters"]["Тип матриці"]["QD-OLED"], 21618415)
        self.assertEqual(c["filters"]["Діагональ екрана"]['27-28"'], 24733)
        card = next(x for x in c["cards"] if "274QP" in x["title"])
        self.assertEqual(card["title"], "MSI MAG 274QP QD-OLED X24")
        self.assertEqual(card["spec"], {"diagonal_in": 26.5, "panel": "QD-OLED", "resolution": "2560x1440", "refresh_hz": 240, "brightness_nits": 200})
        self.assertEqual((card["price_min_uah"], card["price_max_uah"], card["offers_count"]), (20616, 25099, 53))
        self.assertTrue(card["url"].startswith("https://hotline.ua/ua/computer-monitory/"))

    def test_search_page_uses_sr_state(self):
        cards = hotline.parse_search(gz("hotline_search.html.gz"))
        self.assertEqual(len(cards), 48)
        self.assertEqual(cards[0]["title"], "MSI MAG 274QP QD-OLED X24")

    def test_offers_with_installment_banks(self):
        o = hotline.parse_offers(gz("hotline_prices.html.gz"))
        self.assertEqual(o["total"], 53)
        self.assertEqual(o["offers"][0]["price_uah"], 20616)  # sorted by price
        inst = [x for x in o["offers"] if x["installment"]]
        self.assertTrue(inst and "мес" in inst[0]["installment_note"])
        self.assertEqual({x["country"] for x in o["offers"]}, {"UA"})

    def test_parse_spec_edge_cases(self):
        self.assertEqual(hotline.parse_spec(['дисплей: 27"', "IPS", "2560x1440", "16:9", " частота оновлення: 300 (320 - овердрайв) Гц"])["refresh_hz"], 300)
        self.assertEqual(hotline.parse_spec(["Tandem WOLED"])["panel"], "Tandem WOLED")
        self.assertIsNone(hotline.parse_spec([])["diagonal_in"])


class RozetkaParsers(unittest.TestCase):
    def test_search_details_comments(self):
        ids = rozetka.parse_search(js("rozetka_search.json"))
        self.assertEqual(ids[0], 581847193)
        d = rozetka.parse_details(js("rozetka_details.json"))
        self.assertEqual(d[511378054], {"rating": 4.4, "rating_count": 79})  # no seller block in this fixture
        cm = rozetka.parse_comments(js("rozetka_comments.json"))
        self.assertEqual(cm["url"], "https://hard.rozetka.com.ua/msi-mag-274qp-qd-oled-x24/p581847193/")
        self.assertEqual((cm["total_comments"], cm["pages"]), (1, 1))
        self.assertEqual(cm["comments"][0]["mark"], 5)
        self.assertIn("рекомендую", cm["comments"][0]["text"].lower())

    def test_card(self):
        c = rozetka.parse_card(gz("rozetka_card.html.gz"))
        self.assertEqual(c["price_uah"], 21999)
        self.assertEqual(c["availability"], "в наявності")
        self.assertTrue(c["installment"])
        self.assertIn("Rozetka x4", c["installment_note"])
        self.assertIn("ПриватБанк x3", c["installment_note"])
        self.assertEqual(c["seller"], "Rozetka")
        self.assertEqual(c["delivery_scope"], "ua_local")
        self.assertEqual(c["price_note"], "21339 ₴ картою Rozetka")

    def test_seller_from_url(self):
        self.assertEqual(rozetka.seller_from_url("https://hard.rozetka.com.ua/msi-mag-274qp-qd-oled-x24/p581847193/"), "Rozetka")
        self.assertEqual(rozetka.seller_from_url("https://hard.rozetka.com.ua/ua/520016654/p520016654/"), "продавец маркетплейса")
        self.assertEqual(rozetka.seller_from_url(""), "")

    def test_card_eu_marker(self):
        page = '<script type="application/ld+json">{"@type":"Product","offers":{"price":100,"availability":"https://schema.org/InStock"}}</script><p>Продавець: Rozetka EU</p>'
        self.assertEqual(rozetka.parse_card(page)["delivery_scope"], "ua_delivery")


class HtmlShops(unittest.TestCase):
    def test_foxtrot(self):
        r = foxtrot.parse_search(gz("foxtrot_search.html.gz"))
        self.assertEqual(len(r), 15)
        x = next(i for i in r if "274QP QD-OLED" in i["title"])
        self.assertEqual((x["price_uah"], x["price_note"], x["availability"]), (21999, "было 25099 ₴", "в наявності"))
        self.assertEqual(r[0]["rating_count"], 15)
        self.assertTrue(r[0]["installment"])

    def test_moyo(self):
        r = moyo.parse_search(gz("moyo_search.html.gz"))
        self.assertEqual(len(r), 23)
        x = next(i for i in r if "274QP QD-OLED" in i["title"])
        self.assertEqual(x["title"], 'Монітор 26.5" MSI MAG 274QP QD-OLED X24 (9S6-3CFA9T-001)')
        self.assertEqual((x["price_uah"], x["availability"], x["rating"]), (21999, "в наличии", 5.0))

    def test_allo(self):
        r = allo.parse_search(gz("allo_search.html.gz"))
        self.assertEqual(len(r), 3)
        self.assertEqual((r[0]["price_uah"], r[0]["price_note"]), (21999, "было 25099 ₴"))
        self.assertEqual(r[2]["availability"], "немає")


class FetchService(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        os.environ["SHOPPING_HOME"] = self._tmp.name
        core.create_topic("monitor")
        self.sid = core.create_session("monitor", "монитор 27 OLED", "работа: код", geo="ua_local")["session"]["id"]

    def tearDown(self):
        self._tmp.cleanup()
        os.environ.pop("SHOPPING_HOME", None)

    def test_category_ok(self):
        ok = fetch_svc.category_ok
        self.assertEqual(ok("Смартфони", "Смартфони"), (True, ""))
        self.assertEqual(ok("Смартфони і мобільні телефони", "Смартфони")[0], True)   # substring either way
        self.assertFalse(ok("Захисне скло", "Смартфони")[0])                        # accessory
        self.assertFalse(ok("Чохли для смартфонів", None)[0])                         # accessory even without wanted
        self.assertFalse(ok("Планшети", "Смартфони")[0])                              # other product category
        self.assertEqual(ok("", "Смартфони"), (True, ""))                             # unknown → title match decides

    def test_fetch_drops_accessories_by_category(self):
        from shopping.core.sources.comfy import fetcher as comfy
        page = gz("comfy_search_iphone.html.gz")
        with mock.patch.object(comfy, "chromium_dom", return_value=page):
            r = core.fetch_site("monitor", self.sid, "comfy", "iPhone 16 Pro 256", limit=50, category="Смартфони")
        self.assertTrue(r["success"])
        self.assertTrue(all(o.get("category") == "Смартфони" for o in r["offers"]), [o.get("category") for o in r["offers"]])
        self.assertTrue(any("accessory" in d["why"] for d in r["dropped"]) or r["matched"] > 0)
        rows = core.list_findings("monitor", self.sid, group="marketplace")["findings"]
        self.assertTrue(rows and all(x["category"] == "Смартфони" for x in rows))
        self.assertIn("dropped by category", core.get_session("monitor", self.sid)["log_tail"][-1]["detail"])

    def test_matches_model(self):
        self.assertTrue(fetch_svc.matches_model('Монітор 26.5" MSI MAG 274QP QD-OLED X24', "MSI MAG 274QP QD-OLED X24"))
        self.assertFalse(fetch_svc.matches_model("Монітор MSI MAG 274QPF X30MV", "MSI MAG 274QP QD-OLED X24"))
        self.assertTrue(fetch_svc.matches_model("LG UltraGear 27GS95QE-B", "LG 27GS95QE-B"))
        m = fetch_svc.matches_model
        self.assertTrue(m("Смартфон Apple iPhone 16 Pro 256Gb Black Titanium", "iPhone 16 Pro 256"))
        self.assertFalse(m("Смартфон Apple iPhone 16 Pro Max 256Gb Black Titanium", "iPhone 16 Pro 256"))   # variant
        self.assertTrue(m("Смартфон Apple iPhone 16 Pro Max 256Gb Black", "iPhone 16 Pro Max 256"))
        self.assertFalse(m("Samsung Galaxy S25 Ultra 256GB", "Galaxy S25 256"))
        self.assertTrue(m("Samsung Galaxy S25+ 256GB", "Galaxy S25 Plus 256"))
        self.assertFalse(m("Samsung Galaxy S25+ 256GB", "Galaxy S25 256"))

    def test_fetch_foxtrot_stores_only_matching(self):
        with mock.patch.object(foxtrot, "get", return_value=Response(200, gz("foxtrot_search.html.gz"), "u")):
            r = core.fetch_site("monitor", self.sid, "foxtrot", "MSI MAG 274QP QD-OLED X24")
        self.assertTrue(r["success"])
        self.assertEqual((r["hits"], r["matched"], r["stored"]["added"]), (15, 1, 1))
        self.assertEqual(r["offers"][0]["price_uah"], 21999)
        f = core.list_findings("monitor", self.sid, group="marketplace")["findings"]
        self.assertEqual(f[0]["model"], "MSI MAG 274QP QD-OLED X24")
        self.assertEqual(core.get_session("monitor", self.sid)["log_tail"][-1]["event"], "source_done")

    def test_fetch_blocked_logs_and_errors(self):
        with mock.patch.object(foxtrot, "get", return_value=Response(403, "Just a moment", "u")):
            r = core.fetch_site("monitor", self.sid, "foxtrot", "X")
        self.assertFalse(r["success"])
        self.assertEqual(core.get_session("monitor", self.sid)["log_tail"][-1]["event"], "source_blocked")
        self.assertFalse(core.fetch_site("monitor", self.sid, "nosuchsite", "X")["success"])

    def test_fetch_rozetka_returns_reviews(self):
        def fake_json(url, timeout=25):
            if "search.rozetka" in url:
                return js("rozetka_search.json")
            if "getDetails" in url:
                return js("rozetka_details.json")
            return js("rozetka_comments.json")
        with mock.patch.object(rozetka, "get_json", side_effect=fake_json), \
             mock.patch.object(rozetka, "get", return_value=Response(200, gz("rozetka_card.html.gz"), "u")):
            r = core.fetch_site("monitor", self.sid, "rozetka", "MSI MAG 274QP QD-OLED X24", limit=1)
        self.assertEqual(r["matched"], 1)
        self.assertEqual(r["offers"][0]["price_uah"], 21999)
        self.assertEqual(r["offers"][0]["rating_count"], 1)
        self.assertEqual(len(r["reviews"]), 1)
        self.assertNotIn("reviews", core.list_findings("monitor", self.sid)["findings"][0])

    def test_catalog_filters_by_want(self):
        page = gz("hotline_catalog.html.gz")
        with mock.patch.object(hotline, "get", return_value=Response(200, page, "u")):
            r = core.fetch_catalog("monitor", self.sid, "computer/monitory", [24733, 19939994, 21618415],
                                   want={"diagonal_in": [26, 28], "panel_any": ["OLED"], "resolution": "2560x1440", "refresh_min": 100})
        self.assertTrue(r["success"])
        self.assertEqual(r["scanned"], 48)
        self.assertGreater(r["matched"], 5)
        self.assertTrue(all(c["spec"]["refresh_hz"] >= 100 for c in r["candidates"]))
        self.assertEqual(core.get_session("monitor", self.sid)["findings_by_group"], {"aggregator": r["matched"]})
        with mock.patch.object(hotline, "get", return_value=Response(200, page, "u")):
            r2 = core.fetch_catalog("monitor", self.sid, "computer/monitory", [24733], want={"refresh_min": 540})
        self.assertEqual(r2["matched"], 2)  # the two 540 Hz ASUS PG27AQWP

    def test_fetch_hotline_merges_into_catalog_card(self):
        page_cat, page_sr, page_pr = gz("hotline_catalog.html.gz"), gz("hotline_search.html.gz"), gz("hotline_prices.html.gz")
        with mock.patch.object(hotline, "get", return_value=Response(200, page_cat, "u")):
            core.fetch_catalog("monitor", self.sid, "computer/monitory", [24733], want={"refresh_min": 100})
        with mock.patch.object(hotline, "get", side_effect=lambda url, *a, **k: Response(200, page_pr if "tab=prices" in url else page_sr, url)):
            r = core.fetch_site("monitor", self.sid, "hotline", "MSI MAG 274QP QD-OLED X24")
        self.assertEqual(r["stored"], {"added": 0, "merged": 1})
        self.assertTrue(r["offers"][0]["installment"])
        self.assertTrue(r["shops"] and r["shops"][0]["price_uah"] == 20616)
        row = core.list_findings("monitor", self.sid, model="MSI MAG 274QP QD-OLED X24", group="aggregator")["findings"][0]
        self.assertIn("магазинов", row["installment_note"])

    def test_nuxt_state_needs_payload(self):
        with self.assertRaises(Exception):
            nuxt_state("<html></html>")


if __name__ == "__main__":
    unittest.main()
