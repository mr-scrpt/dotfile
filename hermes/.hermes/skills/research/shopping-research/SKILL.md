---
name: shopping-research
description: "Use when the user wants to find/compare goods to buy in Ukraine."
version: 0.3.0
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
in the plugin's `core/sources/<site>/source.yaml` packages. The model's job: run the brief, read
what the tools return, extract nuances from reviews, write the verdict in Russian.

Not for price alerts (`product-price-monitor`) or a quick tier guide (`ukraine-hardware-shopping`).

## Prerequisites

- Plugin `shopping` enabled; its 17 `shop_*` tools are plugin tools → behind progressive
  disclosure. First action of every session: `tool_describe` for the names you will use
  (at least `shop_menu, shop_create_topic, shop_create_session, shop_get_session, shop_sources,
  shop_catalog, shop_fetch, shop_add_findings, shop_log, shop_set_summary, shop_render_report`),
  then call through `tool_call`. Absence from the direct list ≠ disabled.
- Every choice the user makes goes through `shop_menu` (the plugin renders a native pick list:
  arrows / numbers / Space checkboxes / "Other" free text). Never rebuild such lists as text.
  Only if `shop_menu` returns `no_ui` (gateway) ask the same thing as a numbered list in chat.
- `web_search` backend is `ddgs` (keyless). `browser_exec` only for sites marked `fetch: browser`.
- Load this skill ONCE per session; do not re-read it.
- Russian for everything user-facing and for `report.md`.

Entry point for the user: `/shop` (the plugin injects the start prompt) — or any "найди …" message.

## Procedure (fixed order; each step has a done-criterion)

Lists → `shop_menu`; free-form fields (query, purpose, budget…) → one plain question each.

1. Topic — `shop_menu(kind="topics")` → slug or `__new_topic__` → ask slug/title →
   `shop_create_topic`. Done: topic slug chosen.
2. Session — `shop_menu(kind="sessions", topic)` → id or `__new_session__`. Resume →
   `shop_get_session` → say in 2 lines where it stopped (`log_tail`: last `source_done` /
   `source_blocked` / `next`) and continue from the first unfinished step below; if
   `params.sites` is empty the session still needs step 3b.
   Done: session id fixed.
3. Brief (new session) — collect, one question each:
   (a) что ищем + hard spec (`query`, `must`), (b) **назначение** (`purpose`: для чего —
   работа/текст/код/видео/игры/…; mandatory, the tool rejects an empty one), (c) nice-to-have,
   (d) extra conditions (рассрочка, гарантия), (e) budget, (f) geo `ua_local` (default) /
   `ua_delivery`. → `shop_create_session`. Done: `search.json` exists.
3b. Sources — the user decides where to search; you never pick sites for them.
   `shop_menu(kind="probe")` shows every probe-able site by name; the result carries
   `probe: bool` and `only: [...]|null`. Then `shop_menu(kind="sources", query=<query>,
   probe=<probe>, only=<only>)` — the plugin runs the parallel probe first and lists EVERY site
   with its state: hit count / «исключён из зонда» / «нет скрипта — только браузер» /
   «0 — не найдено». Sites without a script can still be chosen (searched via browser). Store the
   answer: `shop_update_params(sites=values)`; `free_text` = extra sites the user typed → add
   to `notes`. Done: `params.sites` non-empty. Steps 4–5 run ONLY on `params.sites`.
4. Candidates — if `hotline` ∈ sites: `shop_sources(group="hotline_filters")` → map the hard spec to filter ids
   (diagonal, panel, resolution; refresh as a range id when it is a lower bound → use the
   `want.refresh_min` instead of a frequency id). `shop_catalog(section, filter_ids, want)`
   where `want` = the numeric hard spec. Result = every model on the UA market matching the
   spec, with min–max price, offers and reviews count. If `matched` > 12, narrow with the user
   (budget / brand / nice-to-have) and re-run; if 0, relax one `must` and re-run.
   If `hotline` ∉ sites (e.g. стройка, инверторы): `shop_probe(query, only=sites)` samples are
   the seed — take the distinct model codes from the titles of the chosen script sites.
   Then `shop_menu(kind="candidates", candidates=[…])` → the user ticks which models to compare.
   Done: 1–12 candidate model codes chosen by the user, `source_done` logged.
5. Offers — for EVERY chosen candidate and EVERY site in `params.sites` with `fetch: script`
   (`shop_sources` says which; today 13 of 18: hotline, ekatalog, pn, rozetka, foxtrot, moyo, allo, citrus,
   eldorado, prom, epicentr, telemart, brain): `shop_fetch(site, model, geo)`. The tool stores matching offers itself and returns
   compact data; you only read it. Chosen sites with `fetch: browser` (comfy, price, ktc, elmir, compx): open the `search` URL in `browser_exec`, take the first exact-model card, store via
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
   how the pick fits the `purpose`. `shop_render_report` (returns path + row counts, not the
   text) → `read_file(path)` → paste the file verbatim to the user + its absolute path.
   Done: `report_path` set.
8. Follow-ups — later questions on the session → research → `shop_add_followup` → answer.

## Token discipline

- Never print raw HTML/JSON from a page; scripted tools already return compact data.
- `shop_render_report` is called once at the end (and once per follow-up); read the file once.
- `web_search` limit 5, exactly the template queries; no improvised queries.
- `shop_probe` costs one compact JSON (~1.5k chars for 8 sites); `browser_exec` costs 10–50× that.
- Read `shop_list_findings` with `fields` when you only need a subset.
- Prefer `shop_fetch`/`shop_catalog` over `browser_exec` whenever `fetch: script`.

## Plugin layout (maintenance)

`~/.hermes/plugins/shopping/` → stow link into `~/Hellkitchen/dotfile/hermes/`:
`core/` (fs → http/model → sources/<site>/ → catalog → sessions/findings → fetch/probe → report/menus),
`ui.py` (the only module touching the host choice panel), `schemas.py`, `tools.py`, `cli.py`,
`data/{geo,reviews}.yaml`, `tests/` (fixtures in `tests/fixtures/*.gz`; run
`~/.hermes/hermes-agent/venv/bin/python -m unittest discover -s tests`).
New site = new folder `core/sources/<site>/` with `source.yaml` (+ `fetcher.py`, fixture, test when
curl works); nothing to register. Then `hermes plugins doctor ~/.hermes/plugins/shopping --ci`.
Refresh hotline ids with `cli.py hotline-filters computer/monitory` → `sources/hotline/source.yaml`.

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

- [ ] `search.json` has a non-empty `purpose` and a non-empty `sites` chosen by the user.
- [ ] `shop_get_session`: status `done`; `findings_by_group` has aggregator, marketplace, review.
- [ ] Every site in `params.sites` was called for every candidate (log has `source_done`/`source_blocked` per site×model).
- [ ] Verdict references the purpose; every nuance traces to a `review` finding.
- [ ] Markdown pasted verbatim + absolute `report.md` path given.
