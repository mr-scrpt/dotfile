---
name: shopping-research
description: "Use when the user wants to find/compare goods to buy in Ukraine."
version: 0.4.0
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

Stateful product research with a FIXED procedure: topic → session → search type (exact model /
pick by spec / pick for an owned device) → brief (incl. purpose) → sources → scripted candidates
→ scripted offers per model → reviews → report.md (ranked picks, per-pick summary, comparison) →
follow-ups. State lives in `~/shopping/` and is written only through `shop_*` tools (plugin
`shopping`). The model does not choose sites, fetch methods or search queries — all of that is
in the plugin's `core/sources/<site>/source.yaml` packages. The model's job: run the brief, read
what the tools return, extract nuances from reviews, write the verdict in Russian.

Not for price alerts (`product-price-monitor`) or a quick tier guide (`ukraine-hardware-shopping`).

## Prerequisites

- Plugin `shopping` enabled; its 19 `shop_*` tools are plugin tools → behind progressive
  disclosure. First action of every session: `tool_describe` for the names you will use
  (at least `shop_menu, shop_create_topic, shop_create_session, shop_update_params, shop_get_session,
  shop_resolve, shop_sources, shop_candidates, shop_fetch, shop_reviews, shop_add_findings, shop_log,
  shop_set_summary, shop_render_report`),
  then call through `tool_call`. Absence from the direct list ≠ disabled.
- Every choice the user makes goes through `shop_menu` (the plugin renders a native pick list:
  arrows / numbers / Space checkboxes / "Other" free text). Never rebuild such lists as text.
  Only if `shop_menu` returns `no_ui` (gateway) ask the same thing as a numbered list in chat.
- `web_search` backend is `ddgs` (keyless). `browser_exec` only for review pages and user-added sites.
- Load this skill ONCE per session; do not re-read it.
- Russian for everything user-facing and for `report.md`.

Entry point for the user: `/shop` (the plugin injects the start prompt) — or any "найди …" message.

## Procedure (fixed order; each step has a done-criterion)

Lists → `shop_menu`; free-form fields (query, purpose, budget…) → one plain question each.
The order of questions is the same for every search; the search TYPE (step 3) decides which
fields are asked and whether steps 3r / 4 run. The user picks the type — never guess it.

1. Topic — `shop_menu(kind="topics")` → slug or `__new_topic__` → ask slug/title →
   `shop_create_topic`. Done: topic slug chosen.
2. Session — `shop_menu(kind="sessions", topic)` → id or `__new_session__`. Resume →
   `shop_get_session` → say in 2 lines where it stopped (`log_tail`: last `source_done` /
   `source_blocked` / `next`) and continue from the first unfinished step below (`params.mode`,
   `sites`, `shortlist` tell you which). Done: session id fixed.
3. Type + brief (new session) — ask «что ищем?» as one free-text line (may contain a URL), then
   `shop_menu(kind="mode", query=<that line>)`:
     `exact`     — one known model («iPhone 17 Pro 256»). Fields: query (model + variant: memory,
                   colour — «любой» if not said), purpose (short), extra (рассрочка…), budget, geo,
                   `shop_menu(condition)` (default new), `shop_menu(reviews)` (suggest `none`).
                   No candidates step: the shortlist is the query itself.
     `spec`      — pick by parameters («монитор 27" 100+ Гц 2K+»). Fields: query + `must` (hard
                   spec), purpose (mandatory, detailed), nice, extra, budget, geo, condition,
                   reviews (suggest `full` for displays/audio, `cards` otherwise).
     `reference` — pick for an owned device. Fields: reference (URL or name) → step 3r, then
                   for EACH wanted thing: name + must/nice (`items`), purpose, extra, budget, geo,
                   condition, reviews.
   → `shop_create_session(query, purpose, must, nice, extra, geo, budget_uah)`, then ONE
   `shop_update_params(mode, condition, reviews, items?, reference?)`. Done: `search.json` has `mode`.
3r. Reference (mode=reference only) — `shop_resolve(reference)` → `{title, url, source, spec}`
   (URL: the site's card, e.g. rozetka characteristics; name: hotline). Show the user title +
   the 5–8 key characteristics in 3 lines and ask «что нужно под него?» (free text, e.g. «инвертор
   и зарядное»). Derive ONE brief per wanted thing from `spec` (e.g. LiFePO4 24 V 100 Ah → инвертор:
   24 В вход, чистый синус, ≥2000 Вт; зарядное: LiFePO4 profile 29.2 В, 20–50 А), show them as
   a numbered list and let the user correct → `shop_update_params(reference=…, items=[…])`.
   Each item then goes through steps 3b–6 as its own spec search (its `must` = the item's must);
   all items share the session and the report. Done: `params.items` non-empty and confirmed.
3b. Sources — the user decides where to search; you never pick sites for them.
   `shop_menu(kind="probe")` shows every probe-able site by name; the result carries
   `probe: bool` and `only: [...]|null`. Then `shop_menu(kind="sources", query=<query or item
   name>, probe=<probe>, only=<only>)` — the plugin runs the parallel probe first and lists EVERY
   site with its state: hit count (by category when the site reports them) / «исключён из
   зонда» / «0 — не найдено». Store the answer: `shop_update_params(sites=values, category=<name
   as the sites call it>)`; `free_text` = extra sites the user typed → add to `notes`.
   Done: `params.sites` non-empty. Steps 4–5 run ONLY on `params.sites`.
4. Candidates (mode=spec, and each reference item) — ONE call:
   `shop_candidates(query=<short product query in Ukrainian: type + 1–2 key words, e.g.
   "монітор 27 OLED", "інвертор 24V", "зарядний пристрій LiFePO4 24V">, category=params.category)`.
   The plugin searches hotline (2 pages) + e-katalog, keeps the chosen category, dedupes by
   model and returns ≤40 rows ranked by market presence: model, price range, offers, reviews,
   `spec` (the aggregator's short characteristics line). Works for any product category — there
   are no per-category filters. Then YOU check each row's `spec` against `must` and keep only
   rows that satisfy it (or where `spec` is silent); if <2 remain, relax one `must` or re-run
   with a broader query; if >15 remain, ask the user to narrow (budget / brand / nice) and
   filter again. Then `shop_menu(kind="candidates", candidates=[kept rows])` → the user ticks
   the models to compare → `shop_update_params(shortlist=values)`. Done: 1–12 models in
   `params.shortlist`. mode=exact: `shortlist = [query]`, no menu.
5. Offers — for EVERY model in the shortlist and EVERY site in `params.sites`:
   `shop_fetch(site, model, geo)`. The tool keeps only cards whose title carries the model code
   without an extra variant word (Pro ≠ Pro Max) AND whose site category is the product itself
   (accessories dropped) AND — with `condition=new` — that are not б/у/відновлений; everything
   dropped is listed in `dropped` with the reason, so say it when a site had only refurbished
   units. All 14 catalogue sites are scripted (comfy runs through local headless Chromium inside
   the plugin). The tool stores offers itself and returns compact data; you only read it. A site
   the user typed as free text (not in the catalogue): open its search in `browser_exec`, take
   the first exact-model card, store via `shop_add_findings`; on "Just a moment"/empty →
   `shop_log(source_blocked)` and move on. Never retry a blocked site more than once.
   Done: each model has ≥1 marketplace finding or a `source_blocked` line per missing site.
   Parallel option for ≥6 models: `delegate_task`, one child per site group, each child uses the
   CLI (`python3 ~/.hermes/plugins/shopping/cli.py fetch <topic> <session> <site> "<model>"`).
   Verify with `shop_get_session` counts after they return.
6. Reviews — governed by `params.reviews`:
   `none` → skip this step entirely (verdict from prices/specs/ratings only).
   `cards` → per shortlisted model ONE call: `shop_reviews(model)`. The plugin reads buyer
   reviews from every stored offer of that model (rozetka, hotline, comfy, moyo, citrus, allo,
   prom, epicentr) in parallel and returns a digest: per-site rating stats + only informative
   sentences (≤2.5k chars, low ratings first, generic praise removed). It stores `<site>-reviews`
   findings itself. Read the digest, write `nuances` from it — never ask for raw texts.
   `full` → `cards` + web: `web_search` for each template in `shop_sources(group="reviews",
   query=<model>)["web_search_queries"]`, limit 5; open at most 3 result pages per model
   (`web_extract` first; `browser_exec` only if empty and the host is not in
   `blocked_for_browser`; YouTube → skill `youtube-content`). One `review` finding per source
   with `model_match` (drop `unclear`), concrete `nuances`, `pros`. Weigh nuances against
   `purpose` (text/code: fringing, flicker, brightness, matte coating; games: VRR, latency).
   Done: ≥1 review finding per shortlisted model (or a `note` that none exist) — unless `none`.
7. Verdict — `shop_set_summary(picks, verdict, caveats, status="done")`. `picks` = the best
   positions in rank order (1–3 per search; for reference mode 1–3 per item, `why` names the
   item), each with `why` (how it fits the purpose/brief), `pros`, `cons` (from reviews and
   specs). `verdict` = the comparison of the picks against each other + the final call.
   The report then renders itself: 1. ranked picks with the cheapest link → 2. one block per
   pick (offers table, aggregator links, pros/cons, review links) → 3. comparison → 4. other
   candidates → 5. follow-ups. `shop_render_report` (returns path + row counts, not the text)
   → `read_file(path)` → paste the file verbatim to the user + its absolute path.
   Done: `report_path` set.
8. Follow-ups — later questions on the session → research → `shop_add_followup` → answer.

## Token discipline

- Never print raw HTML/JSON from a page; scripted tools already return compact data.
- Reviews: `shop_reviews` digest only (~2.5k chars per model) — raw comment lists never enter the context.
- `shop_render_report` is called once at the end (and once per follow-up); read the file once.
- `web_search` limit 5, exactly the template queries; no improvised queries.
- `shop_probe` costs one compact JSON (~1.5k chars for 8 sites); `browser_exec` costs 10–50× that.
- Read `shop_list_findings` with `fields` when you only need a subset.
- Prefer `shop_fetch`/`shop_candidates` over `browser_exec` whenever `fetch: script`.

## Plugin layout (maintenance)

`~/.hermes/plugins/shopping/` → stow link into `~/Hellkitchen/dotfile/hermes/`:
`core/` (fs → http/model → sources/<site>/ → catalog → sessions/findings → fetch/probe → report/menus),
`ui.py` (the only module touching the host choice panel), `schemas.py`, `tools.py`, `cli.py`,
`data/{geo,reviews}.yaml`, `tests/` (fixtures in `tests/fixtures/*.gz`; run
`~/.hermes/hermes-agent/venv/bin/python -m unittest discover -s tests`).
New site = new folder `core/sources/<site>/` with `source.yaml` (+ `fetcher.py`, fixture, test when
curl works); nothing to register. Then `hermes plugins doctor ~/.hermes/plugins/shopping --ci`.

## Pitfalls

- `shop_add_findings` rejects unknown fields / wrong `group`; resend only the failed items.
- Rozetka blocks headless browsers (Cloudflare) — `shop_fetch("rozetka")` uses its APIs via curl;
  never open rozetka in `browser_exec`.
- Hotline lists 27" monitors as 26,5" in `spec`; treat ±0.5" as equal when checking `must`.
- Browser daemon hung ("timed out waiting for the daemon"): `curl 127.0.0.1:<port>/json/list`,
  `/json/close/<id>` for the stuck tab, then `ensure_real_tab()`.
- This SKILL.md is a stow symlink; edit with `patch`, not `skill_manage`.
- `report.md` is regenerated — never edit it by hand.

## Verification

- [ ] `search.json` has `mode`, a non-empty `purpose`, `sites` and `shortlist` chosen by the user
      (reference mode: `reference` + `items` confirmed by the user).
- [ ] `shop_get_session`: status `done`; `findings_by_group` has aggregator, marketplace, review (groups: marketplace | aggregator | review — no separate shops table).
- [ ] Every site in `params.sites` was called for every shortlisted model (log has `source_done`/`source_blocked` per site×model).
- [ ] `picks` carry `why`/`pros`/`cons`; `verdict` compares the picks with each other.
- [ ] Verdict references the purpose; every nuance traces to a `review` finding.
- [ ] Markdown pasted verbatim + absolute `report.md` path given.
