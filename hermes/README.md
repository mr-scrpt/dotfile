# hermes — stow package

Custom Hermes Agent extensions (plugins + skills), linked into `~/.hermes/` with stow.
Bundled Hermes skills stay in `~/.hermes/skills/` unmanaged; only our own live here.

    stow -t ~ hermes                                     # from the repo root
    hermes plugins enable shopping                       # once per machine
    ~/.hermes/hermes-agent/venv/bin/python -m unittest discover -s ~/.hermes/plugins/shopping/tests

## Contents

| path (under ~/.hermes)                     | what                                                                 |
|--------------------------------------------|----------------------------------------------------------------------|
| plugins/shopping/                          | `shop_*` tools + `/shop` + CLI over `~/shopping` research sessions   |
| skills/research/shopping-research/         | workflow skill the agent follows when the user shops for goods in UA |

## Plugin layering (plugins/shopping)

    core/fs.py             io primitives: root(), atomic json/jsonl, slugify, err()
    core/http.py           curl GET, headless-Chromium DOM (Cloudflare sites), HTML/JSON/Nuxt helpers
    core/model.py          domain constants (GROUPS/GEO/STATUSES) + SessionPaths layout
    core/sources/<key>/    ONE FOLDER PER SITE (declarative):
        source.yaml          key, title, group, fetch (script|chromium|browser), search URL, order, notes, filters
        fetcher.py           optional: parse_search(page, meta) + search(query, meta) [+ catalog/offers]
    core/sources/__init__  registry: scans the folders (+ ~/shopping/.config/sources/), validate()
    core/catalog.py        shop_sources document = registry + data/{geo,reviews}.yaml
    core/sessions.py       topics, sessions, params (incl. user-chosen `sites`), journal, summary
    core/findings.py       finding schema/coercion, URL dedup + merge, resume context
    core/fetch.py          shop_fetch / shop_catalog services (scripted sites → compact findings)
    core/probe.py          parallel hit-count probe over scripted sites (status per site)
    core/menus.py          pure menu builders (topics/sessions/probe/sources/candidates)
    core/report.py         report.md + followups rendering (presentation only)
    core/__init__.py       public API — the only thing adapters import
    ui.py                  the only module touching the host choice panel (no 4-choice cap)
    schemas.py             tool schemas (what the model sees)
    tools.py               Hermes tool + slash adapters (dict in → JSON out); /shop starts the flow
    cli.py                 CLI adapter for subagents / manual use (`cli.py probe "<q>" --table`)
    data/geo.yaml, data/reviews.yaml   shared config (override: ~/shopping/.config/<name>.yaml)
    tests/                 unittest suite (SHOPPING_HOME → temp dir; fixtures in tests/fixtures/*.gz)

Adding a site: `mkdir core/sources/<key>`, write `source.yaml`; if the site can be fetched with
curl add `fetcher.py` (+ a gzipped fixture and a parser test) and set `fetch: script`. Nothing
else changes — the registry, probe, menus and `shop_fetch` pick it up. `sources.validate()`
(run by the tests) rejects `fetch: script` without a fetcher.

Rules: behaviour changes go into `core/` with a test; adapters stay thin; no state is
written under the plugin directory (`~/shopping` is the data root, `$SHOPPING_HOME` overrides).
