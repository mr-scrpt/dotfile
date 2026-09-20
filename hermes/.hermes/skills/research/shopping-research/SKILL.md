---
name: shopping-research
description: "Use when the user wants to find/compare goods to buy in Ukraine."
version: 0.9.0
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
4. Criteria — the ONE artefact all three search types converge on. The plugin never guesses a
   parameter and never knows a unit; criteria come from real data, in this order.
   4.1 РАЗВЕДКА ТЕМЫ (mandatory unless the category is trivial and every term is already known):
       `shop_recon(action="brief")` → a prompt + `output_schema`. Run it as a SUBAGENT:
       `delegate_task(goal=<prompt>, output_schema=<output_schema>)`. The subagent samples 2–3
       sources (`shop_source_plan(action="sample")`), searches the web/reviews, and returns
       `{terms, variants, quality, criteria, queries, unknowns}`. Store it with
       `shop_recon(action="store", payload=<its JSON>)` — the plugin validates the contract and
       writes `criteria` + `recon` into the session.
       This step exists because a named technology is NOT common knowledge: Mini-LED is a
       backlight, not a panel type; e-katalog prints it inside `Матриця:` while hotline never
       writes it at all. NEVER decide from memory that a variant "не представлен на рынке" —
       that error already happened once and cost a whole run.
   4.2 What the recon result gives you: `terms` (every spelling), `variants` (kinds and how they
       differ), `quality` (measurable parameters that separate good from bad INSIDE the
       technology — dimming zones, peak brightness — with the direction that is better),
       `criteria` (engine format), `queries` (one short query per alternative), `unknowns`
       (facts no aggregator prints — these go to the reviews step, not to the filter).
   4.3 Material check: `shop_candidates(query|queries, category)` WITHOUT criteria returns
       `observed` — the keys, real values and per-unit ranges of THIS result set. `observed`
       covers EVERYTHING a row states: both the spec text and the row's own fields (e.g.
       `price_min_uah`, `offers_count`), in one flat namespace with no privileged names. Every
       requirement the user gave — бюджет, диагональ, цвет, длина, что угодно — becomes an
       ordinary criterion over a key from `observed`; a numeric field carries no unit, so write
       it as `{"key": "<key from observed>", "any_of": [{"max": N, "unit": ""}]}`. There is no
       special handling for any parameter anywhere in the plugin, and there must never be one. Criteria must
       match that wording: units are compared AS WRITTEN and never converted, so cover every
       spelling (`any_of` with both "Вт" and "кBт"). Alternatives are ONE criterion with
       `either`, never two separate searches; a branch may be a PROXY when a site does not print
       the parameter (hotline: 1000+ кд/м² instead of "Mini LED") — label it as such and verify
       those hits on a source that does print it.
   4.4 SHOW the criteria to the user before searching (`criteria_shown` gives ready lines),
       together with what the recon found (варианты технологии, на что смотреть), and ask for
       corrections. Then `shop_update_params(criteria=[...])`.
   4.5 Apply: `shop_candidates(query|queries, category, criteria)`. Survivors are listed with
       `dropped_by_spec` (reason per rejected model). A card whose spec is silent is KEPT and
       flagged `unverified` — never claim such a model lacks the feature.
       If the answer carries `needs_narrowing` (more than 20 survivors), GO BACK TO THE USER with
       `narrow_suggestions` (which parameters actually split this set, with their values) and
       tighten the criteria BEFORE collecting reviews. Do not silently cut the list yourself.
       Store every survivor: `shop_update_params(shortlist=[all survivors])`.
       mode=exact: `shortlist = [query]`, no candidates call at all.
4b. Per-source plans — the same criteria, expressed in each source's own language.
   `shop_source_plan(action="capabilities", sites=params.sites)` → what each source can do.
   For a source you have not searched before, or whose wording you are unsure of:
   `shop_source_plan(action="sample", site, query)` → its titles + its own `observed`.
   Write one plan per chosen source: `{site, query, criteria?, strict?}` — the query carries the
   parameters in THAT site's words (aggregators take a short type query; marketplaces need the
   parameters inside the text because their result lists have no specs at all), and `criteria`
   may differ per site because each site words its keys differently.
   `shop_source_plan(action="probe", plans)` dry-runs them in parallel: hits vs kept per plan,
   a dropped example, and a `warning` when a source prints no specs (there the query must carry
   everything). Fix the weak queries, then keep the plans for step 5.
5. Offers + reviews for EVERY survivor — ONE call: `shop_compare(models=params.shortlist,
   plans_by_model=<from step 4b, optional>)`. It fetches prices and buyer reviews for ALL of them
   in parallel (politeness is handled by the plugin) and returns one row per model: spec line,
   best price and shop, offers count, rating + review count, complaint signals, `unverified`
   criteria. It refuses above 24 models — that means step 4.5 did not narrow enough.
   NEVER pre-select "finalists" before this step: the model with the best spec sheet may be the
   one buyers complain about, and the one with modest specs may have excellent reviews.
   Done: every model in `params.shortlist` has a row (models with no reviews are listed in
   `no_reviews` — say so rather than hiding them).
6. Deep reviews (only when a model's row is thin and it is a serious contender):
   `shop_reviews(model)` for the full digest, or, with `params.reviews == "full"`, `web_search`
   over `shop_sources(group="reviews", query=<model>)["web_search_queries"]` (limit 5, ≤3 pages
   per model) — this is also where `recon.unknowns` get checked (dimming zones, real brightness),
   since aggregators do not print them. One `review` finding per source with concrete `nuances`.
7. Вердикт — YOU choose the three leaders from the `shop_compare` table, weighing: how well the
   spec matches the purpose, what buyers complain about, price, and how verified the data is.
   Reviews may demote a spec leader — that is the point of collecting them for everyone.
   `shop_set_summary(picks=[3 models with why/pros/cons], verdict=<comparison of the three>,
   caveats=[...], spec_leaders=[{model, why, verdict}])`, where `spec_leaders` are models that
   lead ON PAPER but did not make the three — with the reason (e.g. "360 Гц против 240, но
   жалобы на равномерность подсветки"). The report renders: 1. picks → 2. block per pick →
   3. comparison → 3b. лидеры по характеристикам → 4. все прошедшие критерии → 5. уточнения.
   `shop_render_report` → `read_file(path)` → paste verbatim + the absolute path.
   Done: `report_path` set, picks explained, spec leaders accounted for.
8. Follow-ups — later questions on the session → research → `shop_add_followup` → answer.

## Token discipline

- Never print raw HTML/JSON from a page; scripted tools already return compact data.
- Reviews: `shop_reviews` digest only (~2.5k chars per model) — raw comment lists never enter the context.
- `shop_render_report` is called once at the end (and once per follow-up); read the file once.
- `web_search` limit 5, exactly the template queries; no improvised queries.
- `shop_probe` costs one compact JSON (~1.5k chars for 8 sites); `browser_exec` costs 10–50× that.
- Repeated identical requests are served from the plugin's cache (per-source `cache_ttl`), so
  re-running a step is cheap — but a NEW query to a slow source (e-katalog: ~8 s apart) is not:
  plan the queries you need instead of probing many variants.
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
- Aggregator specs are patchy: a missing parameter is `unverified`, NOT a rejection — never
  claim a model lacks a feature just because its spec line is silent.
- НИКОГДА не спрашивай, какие модели сравнивать. Такого меню больше нет (`kind=candidates`
  возвращает ошибку): отзывы и цены собираются по ВСЕМ прошедшим критерии, тройку лидеров ты
  выбираешь сам по таблице `shop_compare` — в самом конце. Если моделей больше 20 — сужай
  КРИТЕРИИ вместе с пользователем, а не выбирай модели вручную.
- НИЧЕГО не делай без ответа пользователя, когда задал вопрос. Панель ждёт сколько угодно; если
  инструмент всё же вернул `timed_out`, пустой ответ или ошибку — это НЕ ответ и НЕ разрешение
  продолжать: повтори вопрос в чате обычным текстом и жди. Никаких «раз не ответил, решу сам».
- НЕ ЧИНИ ПЛАГИН ВО ВРЕМЯ РАБОТЫ. `shopping` — продукт, которым пользуются другие: его код,
  схемы и этот скилл НЕ правятся из исследовательской сессии, даже если баг очевиден и правка
  в одну строку. Нашёл дефект (инструмент падает, ничего не сохраняет, врёт про успех) —
  `shop_bugreport(title, observed, expected, where, repro, error, severity, workaround)`, скажи
  пользователю одной строкой и продолжай с обходным путём, если он есть; если обойти нельзя —
  останови поиск и сообщи. Правка делается отдельно, в сессии разработки, с тестом и ревью.
  Подозреваешь, что инструмент «сохранил», но не проверил — перечитай `shop_get_session` и
  сверься с тем, что реально лежит в параметрах, прежде чем идти дальше.
- Division of labour, no exceptions: the PLUGIN does everything deterministic (menus, fetching,
  parsing, criteria checking, dedup, review digests, ordering the comparison table, report
  rendering); the MODEL supplies only semantics (topic recon, criteria from `observed`, wording
  for the user, per-source plans, and the final choice of three leaders). Never re-implement a
  plugin step by hand, and never let the plugin decide a trade-off — ranking the leaders is
  judgement, so the plugin deliberately does not do it.
- Никогда не сокращай список перед отзывами. Отзывы собираются по ВСЕМ прошедшим критерии; если
  их больше 20 — вернись к пользователю и сузь критерии, а не отбрасывай модели молча.
- Site search is AND-ish: a full brief as one query returns zero almost everywhere. The plugin
  widens queries itself (`query_used`/`query_tried` in the probe and in shop_candidates) — so a
  site reporting 0 means "this query shape found nothing", not "this shop has no such goods".
  Check `query_used` before concluding a source is empty.
- Politeness is enforced by the plugin (per-host delay + jitter, response cache, cooldown after a
  block), declared per source in `source.yaml: rate:`. Never loop a site by hand, never retry a
  blocked source: `shop_source_plan(action="state")` shows who is cooling down and for how long.
  If a source answers with a captcha, say so and continue without it — do not hammer it.
- Units are strings, not knowledge: the engine converts nothing. If a category writes "3 кBт"
  and another "3000 Вт", cover BOTH in `any_of` — that is why you must read `observed` first.
- Never hardcode a category anywhere: no filter ids, no per-product parsers, no unit tables.
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
