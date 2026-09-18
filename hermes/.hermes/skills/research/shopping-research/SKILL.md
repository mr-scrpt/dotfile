---
name: shopping-research
description: "Use when the user wants to find/compare goods to buy in Ukraine."
version: 0.1.0
author: mr-scrpt, Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [Shopping, Ukraine, Prices, Reviews, Research, Marketplaces]
    related_skills: [ukraine-hardware-shopping, product-price-monitor]
    requires_tools: [shop_list_topics, browser_exec]
---

# Shopping research (Ukraine)

Stateful product research: pick a topic → new or resumed dated session → brief → scrape
marketplaces, shops, price aggregators and model-specific reviews → `report.md` with two
tables + aggregator links + review nuances → follow-ups attached to the same report.
All state lives in `~/shopping/` and is written ONLY through the `shop_*` tools (plugin
`shopping`); never hand-write those files. Not for ongoing price alerts
(`product-price-monitor`) or a quick "what tier to buy" guide (`ukraine-hardware-shopping`).

## Prerequisites

- Plugin `shopping` enabled (`hermes plugins list` shows it). If missing:
  `terminal(command="hermes plugins enable shopping")` and start a new session.
- `shop_*` tools are plugin tools, so they sit behind progressive disclosure: they are NOT in
  the direct tool list. Call `tool_describe(["shop_list_topics", ...])` once at the start (all
  13 names are in the tool_search catalog), then invoke via `tool_call`. Never conclude
  "plugin not enabled" from their absence in the direct list.
- `browser_exec` available — marketplaces and aggregators block plain fetches.
- Language of every user-facing text and of `report.md`: Russian.

## Procedure

Ask questions one at a time, plain text, numbered options (user preference). Never assume a
topic/session when several exist.

### 1. Topic
`shop_list_topics` → show the list numbered + option "новая тема". New → `shop_create_topic(slug, title)`
(slug ASCII: `monitor`, `gpu`, `washing-machine`). Done when one topic slug is chosen.

### 2. Session: new or resume
`shop_list_sessions(topic)` → offer "новый поиск" or one of the sessions (id, status, query,
findings count). Resume → `shop_get_session` → read `params`, `findings_by_group`, `models`,
`log_tail` (last `next`/`source_done`/`source_blocked` events say where to continue) → tell
the user in 2-3 lines where it stopped and confirm continuation. Done when a session id is fixed.

### 3. Brief (new session only)
Collect, one question each: (a) what exactly (`query` + `must`), (b) nice-to-have,
(c) extra conditions (оплата частями / рассрочка, гарантия, б/у ок?), (d) budget,
(e) geo: `ua_local` (default — склад в Украине) or `ua_delivery` (с доставкой в Украину;
Rozetka EU / "Доставка з Європи" count as delivery). → `shop_create_session(...)`.
Done when `search.json` exists with the brief.

### 4. Discover candidate models (aggregators first)
`shop_sources(group="aggregators", query=...)` → open hotline / ek.ua / price.ua / pn.com.ua
search pages in `browser_exec` (recipe + filter IDs for hotline categories:
`ukraine-hardware-shopping/references/hotline-ua.md`). Collect candidate models that satisfy
`must`; for each write an `aggregator` finding (model, url of the aggregator card,
price_min/max, offers_count, rating/rating_count). `shop_add_findings` after EVERY source,
then `shop_log(event="source_done", detail="hotline: N models")`. Blocked source →
`shop_log(event="source_blocked", ...)` and move on. Done when 4-10 candidate model codes are stored.

### 5. Offers — marketplaces and shops (parallelisable)
For each candidate: `shop_sources(group="marketplaces"|"shops", query=<model code>)` → open
search URL in the browser, open the product card, capture: exact title, price, rating +
count, availability, seller (Rozetka vs marketplace seller vs Rozetka EU), installment
("Оплата частинами" block: Моно/Приват, кол-во платежей), delivery_scope. Geo rule:
`ua_local` sessions skip EU/abroad offers entirely; `ua_delivery` keeps them with
`delivery_scope: ua_delivery`. Group `marketplace` = rozetka/comfy/citrus/allo/foxtrot/eldorado/moyo/prom;
group `shop` = everything else. Shops may carry models absent from marketplaces — add them as
new candidates (then run step 6 for them too).

Parallel option: `delegate_task` with one child per group (marketplaces / shops / reviews).
Each child gets: topic, session id, the model list, the geo rule, this section's field list,
and the instruction to store via CLI (`python3 ~/.hermes/plugins/shopping/cli.py add-findings
<topic> <session> --file /tmp/<name>.json`) and to use `browser_exec` (its own `session`
name) for every shop page. Children cannot ask the user. After they return, verify with
`shop_list_findings` counts — child summaries are self-reports.
Done when every candidate has ≥1 offer finding or a `source_blocked` log line.

### 6. Reviews and nuances (per exact model)
`shop_sources(group="reviews", query=<model code>)` → run the `web_search_queries` with
`web_search`, open promising pages (reviews tabs on hotline/rozetka, RTINGS, Reddit,
YouTube comments, forums) in `browser_exec`. One `review` finding per source page with
`model_match` (exact / probable / unclear — drop `unclear`), `nuances` as concrete user
complaints ("скрипит пластик", "засветы по углам", "coil whine", "шумит БП", "гарантийный
отказ"), `pros`. Different suffix/revision = different model unless the source says otherwise.
Done when each shortlisted model has ≥2 review findings or a log note that none exist.

### 7. Verdict and report
`shop_set_summary(verdict, picks[{model, why, url}], caveats, status="done")` →
`shop_render_report` → paste the returned markdown to the user as-is (tables render fine in
Telegram/CLI as plain text) and give the `report.md` path. Done when `report_path` is set.

### 8. Follow-ups
Later questions on the same session ("а что по гарантии у X?", "сравни 1 и 3") → research →
`shop_add_followup(title, question, answer_md)` (re-renders the report with a link) → answer
in chat. If a follow-up changes the shortlist, add findings and re-run step 7.

## Source rules

- Marketplaces, shops, aggregators, hotline/rozetka review tabs: `browser_exec` only
  (`web_extract` gets bot walls or truncated cards). First navigation `new_tab`, then `goto_url`.
- `web_search` only to discover review/forum/video pages; then open them in the browser.
- Cloudflare "Just a moment": wait 5 s and re-read; if it persists → `source_blocked`, move on.
- Prices: capture the timestamped page price, never memory. Say "от X ₴" for aggregator ranges.
- Reviews must name the exact model code; hotline/rozetka review counts are small — always
  add at least one western reviewer (RTINGS / Notebookcheck / TFTCentral) or Reddit.
- Edit the catalogue at `~/shopping/.config/sources.yaml` (via `patch`) when a search URL
  changes or a new shop is worth adding — do not hardcode sites in prompts.

## Layout of the plugin (for maintenance)

`~/.hermes/plugins/shopping/` → stow link into `~/Hellkitchen/dotfile/hermes/` (package `hermes`,
this SKILL.md is linked from the same package):
`core/` = fs → model/catalog → sessions/findings → report (pure functions, dict in/out);
`schemas.py` = what the model sees; `tools.py` = tool/slash adapters; `cli.py` = CLI adapter;
`data/sources.yaml` = seed catalogue; `tests/` = `python -m unittest discover -s tests`
(run with `~/.hermes/hermes-agent/venv/bin/python`). Change behaviour in `core/`, add a
test, then `hermes plugins doctor ~/.hermes/plugins/shopping --ci`.

## Pitfalls

- `shop_add_findings` rejects unknown fields and wrong `group`; read `errors` and resend only
  the failed items. Same URL merges (lists union, price refreshes) — safe to resend.
- Do not batch the whole search in memory: store after each source so a crash/resume keeps data.
- `browser_exec` variables do not persist between calls; dump scraped JSON to `/tmp/` and
  read it back in `execute_code`.
- Rozetka: price on the search grid can differ from the card; open the card. "Rozetka EU" in
  the seller block = delivery scope, not local.
- Rozetka blocks the automated browser with a Cloudflare interstitial (clicking the checkbox
  does not help), but plain `curl -A <Chrome UA>` gets everything: search IDs via
  `https://search.rozetka.com.ua/ua/search/api/v6/?front-end=true&text=<q>&lang=ua`
  (`data.goods[].id`), canonical card URL + rating via
  `https://product-api.rozetka.com.ua/v4/comments/get?front-end=true&goods=<id>&page=1&sort=date&limit=30&lang=ua&type=comment`
  (`data.record.href`, `data.total_comments`, `data.comments[]` — parse with
  `json.loads(raw, strict=False)`), then curl the card HTML (`hard.rozetka.com.ua/...`) and
  strip tags: price sits before "Оплатити частинами", installment lines look like
  "Rozetka / від / 8333 / ₴ / x 3 / ПриватБанк …", seller in each review "Продавець: X".
  `xl-catalog-api…/v4/goods/getDetails` returns only docket/rating, no price.
- Review pages that bot-wall the browser: reddit (www and old), bestbuy, synccomputers;
  `brutreview.com` hangs the CDP tab (do not open). YouTube reviews: fetch the transcript via
  skill `youtube-content` (`uv run --with youtube-transcript-api python …/fetch_transcript.py URL --text-only`).
- Browser daemon stuck ("timed out after 5s waiting for the daemon" on every call, even `js('1+1')`):
  a tab is hung. `curl http://127.0.0.1:<port>/json/list` (port = `--remote-debugging-port` of the
  headless chromium in `ps`), `curl http://127.0.0.1:<port>/json/close/<id>` for the stuck
  page(s), then `ensure_real_tab()` works again. Killing daemons/chromium alone does not help.
  Navigate risky sites with `cdp("Page.navigate", url=…)` + `time.sleep` + `cdp("Page.stopLoading")`
  instead of `goto_url`/`wait_for_load`.
- This SKILL.md is a stow symlink into `~/Hellkitchen/dotfile/hermes/`; `skill_manage` does not
  see it — edit with `patch` on `~/.hermes/skills/research/shopping-research/SKILL.md`.
- Rozetka comments are their own source: store them as a separate `review` finding
  (`source: rozetka-comments`, url = card `/comments/`), not folded into a YouTube/RTINGS record —
  the report shows per-source attribution and the reader must see where each nuance came from.
- Follow-ups live in `followups/`; never edit `report.md` by hand — it is regenerated.

## Verification

- [ ] `shop_get_session` shows status `done`, `findings_by_group` has marketplace, aggregator
      and review entries, `report_path` set.
- [ ] Every table row has a product link, price with date context, and a geo flag consistent
      with the session geo.
- [ ] Every nuance in the report traces to a `review` finding with `model_match` exact/probable.
- [ ] The user received the markdown in chat and the absolute path of `report.md`.
