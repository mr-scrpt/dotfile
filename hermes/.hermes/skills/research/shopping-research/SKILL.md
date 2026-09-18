---
name: shopping-research
description: "Use when the user wants to find/compare goods to buy in Ukraine."
version: 0.2.0
author: mr-scrpt, Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [Shopping, Ukraine, Prices, Reviews, Research, Marketplaces]
    related_skills: [ukraine-hardware-shopping, product-price-monitor, youtube-content]
    requires_tools: [browser_exec]
---

# Shopping research (Ukraine)

Stateful product research with a FIXED procedure: topic → session → brief (incl. purpose) →
scripted candidate discovery on hotline → scripted offers per model → reviews → report.md →
follow-ups. State lives in `~/shopping/` and is written only through `shop_*` tools (plugin
`shopping`). The model does not choose sites, fetch methods or search queries — all of that is
in `~/shopping/.config/sources.yaml` and in the plugin. The model's job: run the brief, read
what the tools return, extract nuances from reviews, write the verdict in Russian.

Not for price alerts (`product-price-monitor`) or a quick tier guide (`ukraine-hardware-shopping`).

## Prerequisites

- Plugin `shopping` enabled; its 15 `shop_*` tools are plugin tools → behind progressive
  disclosure. First action of every session: `tool_describe` for the names you will use
  (at least `shop_list_topics, shop_list_sessions, shop_create_session, shop_get_session,
  shop_sources, shop_catalog, shop_fetch, shop_add_findings, shop_log, shop_set_summary,
  shop_render_report`), then call through `tool_call`. Absence from the direct list ≠ disabled.
- `web_search` backend is `ddgs` (keyless). `browser_exec` only for sites marked `fetch: browser`.
- Load this skill ONCE per session; do not re-read it.
- Russian for everything user-facing and for `report.md`.

## Procedure (fixed order; each step has a done-criterion)

Ask the user one question at a time, plain text, numbered options.

1. Topic — `shop_list_topics` → numbered list + "новая тема". New → `shop_create_topic`.
   Done: topic slug chosen.
2. Session — `shop_list_sessions(topic)` → "новый поиск" or an existing id. Resume →
   `shop_get_session` → say in 2 lines where it stopped (`log_tail`: last `source_done` /
   `source_blocked` / `next`) and continue from the first unfinished step below.
   Done: session id fixed.
3. Brief (new session) — collect, one question each:
   (a) что ищем + hard spec (`query`, `must`), (b) **назначение** (`purpose`: для чего —
   работа/текст/код/видео/игры/…; mandatory, the tool rejects an empty one), (c) nice-to-have,
   (d) extra conditions (рассрочка, гарантия), (e) budget, (f) geo `ua_local` (default) /
   `ua_delivery`. → `shop_create_session`. Done: `search.json` exists.
4. Candidates — `shop_sources(group="hotline_filters")` → map the hard spec to filter ids
   (diagonal, panel, resolution; refresh as a range id when it is a lower bound → use the
   `want.refresh_min` instead of a frequency id). `shop_catalog(section, filter_ids, want)`
   where `want` = the numeric hard spec. Result = every model on the UA market matching the
   spec, with min–max price, offers and reviews count. If `matched` > 12, narrow with the user
   (budget / brand / nice-to-have) and re-run; if 0, relax one `must` and re-run.
   Done: 3–12 candidate model codes, `source_done` logged by the tool.
5. Offers — for EVERY candidate and EVERY site with `fetch: script` in `shop_sources`
   (`marketplaces` + `aggregators`; today: hotline, rozetka, foxtrot, moyo, allo):
   `shop_fetch(site, model, geo)`. The tool stores matching offers itself and returns compact
   data; you only read it. Sites with `fetch: browser` (comfy, citrus, eldorado, prom, shops
   table): open the `search` URL in `browser_exec`, take the first exact-model card, store via
   `shop_add_findings`; on "Just a moment"/empty → `shop_log(source_blocked)` and move on.
   Never retry a blocked site more than once. Done: each candidate has ≥1 marketplace finding
   or a `source_blocked` line per missing site.
   Parallel option for ≥6 candidates: `delegate_task`, one child per site group, each child
   uses the CLI (`python3 ~/.hermes/plugins/shopping/cli.py fetch <topic> <session> <site>
   "<model>"`). Verify with `shop_get_session` counts after they return.
6. Reviews — per candidate, in this order and nothing else:
   (a) `shop_fetch("rozetka")` already returned `reviews[]`; `shop_fetch("hotline")` returned
   per-shop offers — read them. (b) `web_search` for each template in
   `shop_sources(group="reviews", query=<model>)["web_search_queries"]`, `limit` = its
   `web_search_limit` (5). (c) Open at most 3 result pages per model: `web_extract` first; if
   empty/bot-wall → `browser_exec` unless the host is in `blocked_for_browser`; YouTube →
   skill `youtube-content` transcript. (d) One `review` finding per source with `model_match`
   (drop `unclear`), `nuances` as concrete user complaints, `pros`; rozetka comments →
   `source: rozetka-comments`. Weigh nuances against `purpose` (text/code: fringing, flicker,
   brightness, matte coating; games: VRR, latency). Done: ≥2 review findings per shortlisted
   model or a `note` that none exist.
7. Verdict — `shop_set_summary(verdict, picks, caveats, status="done")`: verdict must state
   how the pick fits the `purpose`. `shop_render_report` → paste the returned markdown
   verbatim + the `report.md` path. Done: `report_path` set.
8. Follow-ups — later questions on the session → research → `shop_add_followup` → answer.

## Token discipline

- Never print raw HTML/JSON from a page; scripted tools already return compact data.
- `web_search` limit 5, exactly the template queries; no improvised queries.
- Read `shop_list_findings` with `fields` when you only need a subset.
- Prefer `shop_fetch`/`shop_catalog` over `browser_exec` whenever `fetch: script`.

## Plugin layout (maintenance)

`~/.hermes/plugins/shopping/` → stow link into `~/Hellkitchen/dotfile/hermes/`:
`core/` (fs → http → model/catalog → sessions/findings → fetchers/* → fetch → report),
`schemas.py`, `tools.py`, `cli.py`, `data/sources.yaml`, `tests/` (fixtures in
`tests/fixtures/*.gz`; run `~/.hermes/hermes-agent/venv/bin/python -m unittest discover -s tests`).
New site: add `core/fetchers/<site>.py` (parse_search + search), a fixture, a test, register in
`fetchers/__init__.py`, flip `fetch: script` in `data/sources.yaml`, then
`hermes plugins doctor ~/.hermes/plugins/shopping --ci`. Refresh hotline ids with
`cli.py hotline-filters computer/monitory`.

## Pitfalls

- `shop_add_findings` rejects unknown fields / wrong `group`; resend only the failed items.
- Rozetka blocks headless browsers (Cloudflare) — `shop_fetch("rozetka")` uses its APIs via curl;
  never open rozetka in `browser_exec`.
- Hotline "27"" monitors are 26.5" on the card; `want.diagonal_in` must be a range ([26, 28]).
- Browser daemon hung ("timed out waiting for the daemon"): `curl 127.0.0.1:<port>/json/list`,
  `/json/close/<id>` for the stuck tab, then `ensure_real_tab()`.
- This SKILL.md is a stow symlink; edit with `patch`, not `skill_manage`.
- `report.md` is regenerated — never edit it by hand.

## Verification

- [ ] `search.json` has a non-empty `purpose`.
- [ ] `shop_get_session`: status `done`; `findings_by_group` has aggregator, marketplace, review.
- [ ] Every scripted site was called for every candidate (log has `source_done`/`source_blocked` per site×model).
- [ ] Verdict references the purpose; every nuance traces to a `review` finding.
- [ ] Markdown pasted verbatim + absolute `report.md` path given.
