"""Tests for the shopping plugin core + adapters. Run:
    SHOPPING_HOME=/tmp/x  ~/.hermes/hermes-agent/venv/bin/python -m pytest ~/.hermes/plugins/shopping/tests -q
(HOME override not needed — the suite sets SHOPPING_HOME to a temp dir itself.)
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

PLUGINS_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PLUGINS_DIR))

from shopping import core, cli, tools  # noqa: E402
from shopping.core import findings as F  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        os.environ["SHOPPING_HOME"] = self._tmp.name
        core.create_topic("monitor", "Мониторы")
        self.sid = core.create_session("monitor", 'монитор 27" OLED', "работа: текст, код", must=["OLED"], geo="ua_local")["session"]["id"]

    def tearDown(self):
        self._tmp.cleanup()
        os.environ.pop("SHOPPING_HOME", None)

    def add(self, *rows):
        return core.add_findings("monitor", self.sid, list(rows))


OFFER = {"group": "marketplace", "source": "rozetka", "title": "LG UltraGear 27GS95QE-B", "model": "LG 27GS95QE-B",
         "url": "https://rozetka.com.ua/ua/p1/?utm_source=x", "price_uah": "31 999", "rating": 4.8, "rating_count": 12,
         "seller": "Rozetka", "installment": True, "installment_note": "Моно 10"}


class TopicsSessions(Base):
    def test_topic_validation_and_idempotency(self):
        self.assertFalse(core.create_topic("Bad Slug")["success"])
        self.assertFalse(core.create_topic("monitor")["created"])
        self.assertEqual([t["slug"] for t in core.list_topics()["topics"]], ["monitor"])

    def test_session_id_is_dated_and_unique(self):
        self.assertTrue(self.sid.startswith("20"))
        sid2 = core.create_session("monitor", 'монитор 27" OLED', "работа")["session"]["id"]
        self.assertNotEqual(self.sid, sid2)
        self.assertTrue(sid2.endswith("-2"))
        self.assertEqual(len(core.list_sessions("monitor")["sessions"]), 2)

    def test_session_requires_topic_and_geo(self):
        self.assertFalse(core.create_session("nope", "x", "p")["success"])
        self.assertFalse(core.create_session("monitor", "x", "p", geo="mars")["success"])
        self.assertFalse(core.create_session("monitor", "  ", "p")["success"])

    def test_update_params_and_status(self):
        r = core.update_params("monitor", self.sid, status="searching", budget_uah=35000)
        self.assertEqual(r["session"]["params"]["budget_uah"], 35000)
        self.assertEqual(r["session"]["status"], "searching")
        self.assertFalse(core.update_params("monitor", self.sid, bogus=1)["success"])
        self.assertFalse(core.update_params("monitor", self.sid, status="weird")["success"])

    def test_resume_context(self):
        self.add(OFFER)
        core.log_event("monitor", self.sid, "next", "comfy")
        g = core.get_session("monitor", self.sid)
        self.assertEqual(g["findings_by_group"], {"marketplace": 1})
        self.assertEqual(g["models"], ["LG 27GS95QE-B"])
        self.assertEqual(g["log_tail"][-1]["event"], "next")
        self.assertIsNone(g["report_path"])
        self.assertFalse(core.get_session("monitor", "nope")["success"])


class Findings(Base):
    def test_coerce_and_validate(self):
        r = self.add(OFFER, {"group": "bogus", "url": "http://x"}, {"group": "marketplace", "title": "t"},
                     {"group": "marketplace", "url": "u", "title": "t", "price_uah": "abc"})
        self.assertEqual((r["added"], r["merged"], len(r["errors"])), (1, 0, 3))
        f = core.list_findings("monitor", self.sid)["findings"][0]
        self.assertEqual(f["price_uah"], 31999)
        self.assertEqual(f["id"], 1)
        self.assertEqual(core.get_session("monitor", self.sid)["session"]["status"], "searching")

    def test_url_dedup_merges_lists_and_refreshes_price(self):
        self.add(OFFER)
        r = self.add({"group": "marketplace", "title": "dup", "url": "https://rozetka.com.ua/ua/p1/",
                      "price_uah": 29999, "nuances": ["засветы", "Засветы"], "cons": ["дорого"]})
        self.assertEqual((r["added"], r["merged"], r["total"]), (0, 1, 1))
        f = core.list_findings("monitor", self.sid)["findings"][0]
        self.assertEqual(f["title"], "LG UltraGear 27GS95QE-B")  # identity kept
        self.assertEqual(f["price_uah"], 29999)                   # price refreshed
        self.assertEqual(f["nuances"], ["засветы"])               # case-insensitive union
        self.assertEqual(f["cons"], ["дорого"])

    def test_normalizers(self):
        self.assertEqual(F.normalize_url("HTTPS://Rozetka.com.ua/ua/p1/?utm_source=a&b=1"), "https://rozetka.com.ua/ua/p1?b=1")
        self.assertEqual(F.normalize_model("lg 27gs95qe-b"), "LG27GS95QEB")

    def test_fmt_rating_without_score(self):
        from shopping.core.report import fmt_rating
        self.assertEqual(fmt_rating({"rating": None, "rating_count": 1}), "— (1 отз.)")
        self.assertEqual(fmt_rating({"rating": 4.4, "rating_count": 79}), "4.4 (79)")
        self.assertEqual(fmt_rating({"rating": 5.0}), "5")
        self.assertEqual(fmt_rating({}), "—")

    def test_decimal_prices_are_truncated_not_glued(self):
        r = core.add_findings("monitor", self.sid, [dict(OFFER, url="https://x/dec", price_min_uah=10796.55, price_uah=None)])
        self.assertEqual(r["added"], 1)
        row = [f for f in core.list_findings("monitor", self.sid)["findings"] if f["url"].endswith("/dec")][0]
        self.assertEqual(row["price_min_uah"], 10796)

    def test_filters(self):
        self.add(OFFER, {"group": "review", "model": "lg-27gs95qe-b", "url": "https://r/1", "nuances": ["coil whine"]})
        self.assertEqual(core.list_findings("monitor", self.sid, group="review")["count"], 1)
        self.assertEqual(core.list_findings("monitor", self.sid, model="LG 27GS95QE B")["count"], 2)
        rows = core.list_findings("monitor", self.sid, fields=["url"])["findings"]
        self.assertEqual(set(rows[0]), {"url"})


class Report(Base):
    def test_render_picks_per_pick_blocks_and_comparison(self):
        self.add(OFFER,
                 {"group": "marketplace", "source": "telemart", "model": "LG 27GS95QE-B", "url": "https://t/1", "price_uah": 30500},
                 {"group": "aggregator", "source": "hotline", "model": "LG 27GS95QE-B", "url": "https://h/1",
                  "price_min_uah": 29999, "price_max_uah": 34500, "offers_count": 17},
                 {"group": "review", "source": "reddit", "model": "LG 27GS95QE-B", "url": "https://r/1",
                  "nuances": ["coil whine"], "pros": ["чёрный OLED"], "model_match": "exact"},
                 {"group": "marketplace", "source": "moyo", "model": "MSI MAG 271QPX", "url": "https://m/9", "price_uah": 28000, "rating": 4.5, "rating_count": 3})
        core.set_summary("monitor", self.sid, "LG лучше по тексту; MSI дешевле, но глянец.",
                         [{"model": "LG 27GS95QE-B", "why": "под текст и код", "cons": ["нет KVM"]}], ["цены на 18.09"])
        md = core.render_report("monitor", self.sid, full=True)["markdown"]
        for h in ("## 1. Лучшие позиции", "## 2. По каждой позиции", "## 3. Сравнение и вывод", "## 4. Остальные кандидаты"):
            self.assertIn(h, md)
        self.assertIn("1. **LG 27GS95QE-B** — от 30 500 ₴ · [telemart](https://t/1) — под текст и код", md)   # ranked list with the cheapest link
        self.assertIn("### LG 27GS95QE-B — от 30 500 ₴", md)
        self.assertIn("| [rozetka](https://rozetka.com.ua/ua/p1/?utm_source=x) | 31 999 ₴ | 4.8 (12) | да: Моно 10 | Rozetka |", md)
        self.assertIn("Агрегаторы: [hotline](https://h/1) 29 999 – 34 500 ₴, 17 предл.", md)
        self.assertIn("- ＋ чёрный OLED", md)
        self.assertIn("- ⚠ coil whine", md)
        self.assertIn("- ⚠ нет KVM", md)                    # pick-level cons from the summary
        self.assertIn("Отзывы: [reddit](https://r/1)", md)
        self.assertIn("LG лучше по тексту", md)
        self.assertIn("| MSI MAG 271QPX | 28 000 ₴ | [moyo](https://m/9) | 4.5 (3) |", md)   # non-pick → "others" table
        self.assertLess(md.index("## 1."), md.index("## 2."))
        compact = core.render_report("monitor", self.sid)
        self.assertNotIn("markdown", compact)
        self.assertEqual(compact["rows"]["marketplace"], 3)
        self.assertEqual((compact["picks"], compact["others"]), (["LG 27GS95QE-B"], 1))
        self.assertTrue(Path(core.get_session("monitor", self.sid)["report_path"]).exists())

    def test_pick_offers_collapse_per_seller_and_hide_zero_rating(self):
        base = {"group": "marketplace", "source": "rozetka", "model": "LG 27GS95QE-B"}
        self.add(dict(base, url="https://r/a", title="LG A", price_uah=25000, seller="Rozetka", rating=4.4, rating_count=79),
                 dict(base, url="https://r/b", title="LG B", price_uah=25100, seller="продавец маркетплейса"),
                 dict(base, url="https://r/c", title="LG C", price_uah=24900, seller="продавец маркетплейса"),
                 dict(base, url="https://r/d", title="LG D", price_uah=24000, seller="продавец маркетплейса", availability="немає"))
        core.set_summary("monitor", self.sid, "ok", [{"model": "LG 27GS95QE-B", "why": "x"}])
        md = core.render_report("monitor", self.sid, full=True)["markdown"]
        rows = [l for l in md.splitlines() if l.startswith("| [rozetka]")]
        self.assertEqual(len(rows), 2)                      # Rozetka + one marketplace-seller row
        self.assertIn("24 900 ₴", rows[0])                  # cheapest in-stock third-party wins
        self.assertIn("(+2)", rows[0])
        self.assertIn("| — |", rows[0])                     # no "0 (0)" rating
        self.assertIn("4.4 (79)", rows[1])
        self.assertIn("### LG 27GS95QE-B — от 24 900 ₴", md)

    def test_empty_report_and_followup(self):
        md = core.render_report("monitor", self.sid, full=True)["markdown"]
        self.assertIn("_итог ещё не подведён_", md)
        self.assertNotIn("## 4.", md)
        self.assertNotIn("## 5.", md)
        r = core.add_followup("monitor", self.sid, "Гарантия LG", "что по гарантии?", "3 года.")
        self.assertTrue(Path(r["path"]).name.startswith("01_"))
        md = Path(r["report"]).read_text(encoding="utf-8")
        self.assertIn("## 5. Уточнения", md)
        self.assertIn("[Гарантия LG](followups/01_", md)
        self.assertEqual(core.get_session("monitor", self.sid)["followups"], [Path(r["path"]).name])


class Sources(Base):
    def test_catalogue_document_and_templates_filled(self):
        r = core.get_sources("marketplaces", "LG 27GS95QE-B")
        self.assertTrue(Path(r["sources_dir"]).is_dir())
        self.assertEqual(r["sources"]["marketplaces"]["rozetka"]["search"],
                         "https://rozetka.com.ua/ua/search/?text=LG+27GS95QE-B")
        self.assertIn('"LG 27GS95QE-B" review', core.get_sources("reviews", "LG 27GS95QE-B")["sources"]["reviews"]["web_search_queries"])
        self.assertEqual(core.get_sources("marketplaces")["sources"]["marketplaces"]["rozetka"]["fetch"], "script")
        self.assertFalse(core.get_sources("nope")["success"])
        self.assertIn("geo", core.get_sources()["sources"])


class Adapters(Base):
    def test_tool_handlers_return_json_and_swallow_errors(self):
        out = json.loads(tools.HANDLERS["shop_list_topics"]({}))
        self.assertEqual(out["topics"][0]["slug"], "monitor")
        out = json.loads(tools.HANDLERS["shop_update_params"]({"topic": "monitor", "session": self.sid, "status": "done"}))
        self.assertEqual(out["session"]["status"], "done")
        out = json.loads(tools.HANDLERS["shop_add_findings"]({"topic": "monitor", "session": self.sid, "findings": "not-a-list"}))
        self.assertFalse(out["success"])
        self.assertIn("error", out)

    def test_every_schema_has_a_handler(self):
        from shopping import schemas
        self.assertEqual({s["name"] for s in schemas.ALL}, set(tools.HANDLERS))

    def test_slash_command(self):
        self.assertIn("monitor", tools.make_slash_shop(lambda t: True)("status " + ""))
        self.assertIn(self.sid, tools.make_slash_shop(lambda t: True)("status " + "monitor"))
        self.assertIn("findings_total", tools.make_slash_shop(lambda t: True)("status " + f"monitor {self.sid}"))
        sent = []
        self.assertIn("Запускаю", tools.make_slash_shop(lambda t: sent.append(t) or True)(""))
        self.assertIn("shopping-research", sent[0])
        self.assertIn("Не удалось", tools.make_slash_shop(lambda t: False)("start"))
        self.assertIn("not found", tools.make_slash_shop(lambda t: True)("status " + "monitor nope"))

    def test_cli_roundtrip(self):
        out = cli.run(cli.build_parser().parse_args(["add-findings", "monitor", self.sid, "--json", json.dumps([OFFER])]))
        self.assertEqual(out["added"], 1)
        out = cli.run(cli.build_parser().parse_args(["render", "monitor", self.sid]))
        self.assertNotIn("markdown", out)
        self.assertTrue(Path(out["path"]).exists())


if __name__ == "__main__":
    unittest.main()
