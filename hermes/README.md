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

    core/fs.py         io primitives: root(), atomic json/jsonl, slugify, err()
    core/model.py      domain constants (GROUPS/GEO/STATUSES) + SessionPaths layout
    core/catalog.py    sources.yaml: seed → ~/shopping/.config/sources.yaml, URL templates
    core/sessions.py   topics, sessions, params, journal, summary
    core/findings.py   finding schema/coercion, URL dedup + merge, resume context
    core/report.py     report.md + followups rendering (presentation only)
    core/__init__.py   public API — the only thing adapters import
    schemas.py         tool schemas (what the model sees)
    tools.py           Hermes tool + slash adapters (dict in → JSON out)
    cli.py             CLI adapter for subagents / manual use
    data/sources.yaml  seed catalogue (edit the copy in ~/shopping/.config, not this)
    tests/             unittest suite (SHOPPING_HOME → temp dir)

Rules: behaviour changes go into `core/` with a test; adapters stay thin; no state is
written under the plugin directory (`~/shopping` is the data root, `$SHOPPING_HOME` overrides).
