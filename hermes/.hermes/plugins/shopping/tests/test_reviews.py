"""Tests: reviews service (condense → digest, collect over stored offers) and per-site review parsers."""
from __future__ import annotations

import gzip
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from shopping import core  # noqa: E402
from shopping.core import reviews as rv  # noqa: E402
from shopping.core.sources.comfy import fetcher as comfy  # noqa: E402
from shopping.core.sources.moyo import fetcher as moyo  # noqa: E402
from shopping.core.sources.rozetka import fetcher as rozetka  # noqa: E402

FIX = Path(__file__).parent / "fixtures"


def gz(name: str) -> str:
    return gzip.open(FIX / name, "rt", encoding="utf-8").read()


class Parsers(unittest.TestCase):
    def test_comfy_review_page(self):
        d = comfy.parse_reviews(gz("comfy_reviews.html.gz"))
        self.assertEqual(d["total"], 21)
        self.assertEqual(d["avg"], 4.81)
        self.assertEqual(d["distribution"], {5: 19, 4: 1, 3: 0, 2: 1, 1: 0})
        self.assertEqual(len(d["reviews"]), 5)
        self.assertEqual(d["reviews"][0]["rating"], 5)
        self.assertTrue(d["reviews"][0]["verified"])

    def test_moyo_card_reviews_skip_questions(self):
        d = moyo.parse_reviews(gz("moyo_card.html.gz"))
        self.assertEqual(d["total"], 4)
        self.assertEqual(len(d["reviews"]), 4)                      # 2 Q&A entries dropped
        self.assertTrue(all(r["rating"] for r in d["reviews"]))
        self.assertIn("OLED", d["reviews"][1]["pros"])

    def test_rozetka_reviews_needs_goods_id(self):
        with self.assertRaises(rozetka.FetchError):
            rozetka.reviews("https://rozetka.com.ua/ua/no-id/")


class Condense(unittest.TestCase):
    def test_noise_dropped_signal_kept(self):
        data = {"total": 40, "avg": None, "distribution": None, "reviews": [
            {"rating": 5, "text": "Все супер, рекомендую! Дякую!", "pros": "", "cons": "", "verified": True},
            {"rating": 5, "text": "Текст чіткий, очі менше втомлюються, але є легкі засвіти по кутах у темряві.", "pros": "", "cons": "", "verified": True},
            {"rating": 2, "text": "Через місяць з'явився битий піксель, сервіс тягне з гарантією.", "pros": "", "cons": "Скрипить пластик підставки", "verified": False},
            {"rating": 5, "text": "Текст чіткий, очі менше втомлюються, але є легкі засвіти по кутах у темряві.", "pros": "", "cons": "", "verified": True},
        ]}
        summ, sig = rv.condense("rozetka", "https://r/1", data)
        self.assertEqual(summ["total"], 40)
        self.assertEqual(summ["fetched"], 4)
        self.assertEqual(summ["avg"], 4.25)
        self.assertEqual(summ["distribution"], {5: 3, 2: 1})
        self.assertEqual(summ["verified_share"], 0.75)
        texts = [s["text"] for s in sig]
        self.assertEqual(len(texts), 3)                                  # dup dropped, noise dropped
        self.assertTrue(any(t.startswith("− Скрипить") for t in texts))
        self.assertTrue(any("битий піксель" in t for t in texts))
        self.assertFalse(any("рекомендую" in t for t in texts))


class Collect(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        os.environ["SHOPPING_HOME"] = self._tmp.name
        core.create_topic("monitor")
        self.sid = core.create_session("monitor", "монитор 27 OLED", "код")["session"]["id"]
        core.add_findings("monitor", self.sid, [
            {"group": "marketplace", "source": "rozetka", "model": "LG 27GS95QE-B", "url": "https://rozetka.com.ua/ua/x/p1/", "rating_count": 12},
            {"group": "marketplace", "source": "moyo", "model": "LG 27GS95QE-B", "url": "https://www.moyo.ua/ua/x.html", "rating_count": 0},
            {"group": "marketplace", "source": "comfy", "model": "LG 27GS95QE-B", "url": "https://comfy.ua/ua/x.html", "rating_count": 3},
            {"group": "marketplace", "source": "foxtrot", "model": "LG 27GS95QE-B", "url": "https://f/x", "rating_count": 9},   # no reviews() in fetcher
        ])

    def tearDown(self):
        self._tmp.cleanup()
        os.environ.pop("SHOPPING_HOME", None)

    def test_collect_parallel_and_stores_digest(self):
        rz = {"total": 12, "avg": None, "distribution": None, "reviews": [
            {"rating": 4, "text": "Мерехтіння при VRR у меню ігор, лікується вимкненням Adaptive Sync.", "pros": "", "cons": "", "verified": True}]}
        cf = {"total": 3, "avg": 4.3, "distribution": {5: 2, 3: 1}, "reviews": [
            {"rating": 3, "text": "Все ок.", "pros": "", "cons": "Гуде блок живлення під навантаженням", "verified": True}]}
        calls = []

        def fake_rz(url, pages=3):
            calls.append(("rozetka", url)); return rz

        def fake_cf(url):
            calls.append(("comfy", url)); return cf

        with mock.patch.object(rozetka, "reviews", side_effect=fake_rz), mock.patch.object(comfy, "reviews", side_effect=fake_cf), \
             mock.patch.object(moyo, "reviews", side_effect=AssertionError("must not be called: 0 reviews on card")):
            r = core.collect_reviews("monitor", self.sid, "LG 27GS95QE-B")
        self.assertTrue(r["success"])
        self.assertEqual(sorted(c[0] for c in calls), ["comfy", "rozetka"])
        self.assertEqual({s["site"] for s in r["sources"]}, {"rozetka", "comfy"})
        self.assertEqual(r["errors"], [])                                    # foxtrot silently skipped
        self.assertEqual(r["signals"][0]["rating"], 3)                        # low ratings first
        stored = core.list_findings("monitor", self.sid, group="review")["findings"]
        self.assertEqual({f["source"] for f in stored}, {"rozetka-reviews", "comfy-reviews"})
        cfrow = next(f for f in stored if f["source"] == "comfy-reviews")
        self.assertEqual(cfrow["rating"], 4.3)
        self.assertEqual(cfrow["rating_count"], 3)
        self.assertIn("Гуде блок живлення під навантаженням", cfrow["nuances"])
        self.assertIn("5★:2", cfrow["notes"])
        self.assertEqual(core.get_session("monitor", self.sid)["log_tail"][-1]["event"], "source_done")

    def test_collect_limits_to_sites_and_reports_errors(self):
        with mock.patch.object(rozetka, "reviews", side_effect=RuntimeError("boom")):
            r = core.collect_reviews("monitor", self.sid, "LG 27GS95QE-B", sites=["rozetka"])
        self.assertEqual(r["sources"], [])
        self.assertEqual(r["errors"][0]["site"], "rozetka")
        self.assertIn("boom", r["errors"][0]["error"])

    def test_reviews_mode_param(self):
        self.assertTrue(core.update_params("monitor", self.sid, reviews="none")["success"])
        self.assertFalse(core.update_params("monitor", self.sid, reviews="lots")["success"])
        m = core.menus.reviews_menu()
        self.assertEqual([i["value"] for i in m["items"]], ["none", "cards", "full"])


if __name__ == "__main__":
    unittest.main()
