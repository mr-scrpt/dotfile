"""Tool schemas for the shopping plugin (what the model sees). Kept terse: every char here is paid on each
tool_describe; long guidance lives in the shopping-research skill."""

_TOPIC = {"type": "string", "description": "topic slug"}
_SESSION = {"type": "string", "description": "session id"}
_GEO = {"type": "string", "enum": ["ua_local", "ua_delivery"], "description": "ua_local=stock in UA (default); ua_delivery=+shipped to UA"}
_STR_LIST = {"type": "array", "items": {"type": "string"}}
_TS = {"topic": _TOPIC, "session": _SESSION}

FINDING = {
    "type": "object",
    "properties": {
        "group": {"type": "string", "enum": ["marketplace", "aggregator", "review"]},
        "source": {"type": "string", "description": "site key: rozetka, hotline, rtings, reddit…"},
        "title": {"type": "string"},
        "model": {"type": "string", "description": "exact model code; links reviews to offers"},
        "url": {"type": "string", "description": "dedup key"},
        "price_uah": {"type": "integer"}, "price_min_uah": {"type": "integer"}, "price_max_uah": {"type": "integer"},
        "price_note": {"type": "string"},
        "rating": {"type": "number"}, "rating_count": {"type": "integer"}, "offers_count": {"type": "integer"},
        "availability": {"type": "string"}, "seller": {"type": "string"}, "delivery_scope": _GEO,
        "category": {"type": "string", "description": "site category of the card (e.g. Смартфони)"},
        "installment": {"type": "boolean"}, "installment_note": {"type": "string"},
        "pros": _STR_LIST, "cons": _STR_LIST,
        "nuances": {**_STR_LIST, "description": "concrete user-reported issues for THIS model"},
        "review_sources": _STR_LIST, "notes": {"type": "string"},
        "model_match": {"type": "string", "enum": ["exact", "probable", "unclear"]},
    },
    "required": ["group", "url"],
}

SHOP_LIST_TOPICS = {"name": "shop_list_topics", "description": "List research topics under ~/shopping. Call first.",
                    "parameters": {"type": "object", "properties": {}}}

SHOP_CREATE_TOPIC = {"name": "shop_create_topic", "description": "Create a topic folder (idempotent).",
                     "parameters": {"type": "object", "properties": {"slug": {"type": "string", "description": "[a-z0-9-]"}, "title": {"type": "string"}}, "required": ["slug"]}}

SHOP_LIST_SESSIONS = {"name": "shop_list_sessions", "description": "List dated sessions of a topic (status, query, findings count).",
                      "parameters": {"type": "object", "properties": {"topic": _TOPIC}, "required": ["topic"]}}

SHOP_CREATE_SESSION = {
    "name": "shop_create_session",
    "description": "Start a dated session with the brief. purpose is mandatory (what the item is for).",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC, "query": {"type": "string"},
        "purpose": {"type": "string", "description": "e.g. 'работа: текст, код, YouTube; не игры'"},
        "must": _STR_LIST, "nice": _STR_LIST, "extra": {**_STR_LIST, "description": "e.g. оплата частями"},
        "geo": _GEO, "budget_uah": {"type": "integer"}, "notes": {"type": "string"}, "slug": {"type": "string"},
        "sites": {**_STR_LIST, "description": "chosen site keys (from shop_menu sources); may be set later via shop_update_params"},
    }, "required": ["topic", "query", "purpose"]},
}

SHOP_GET_SESSION = {"name": "shop_get_session", "description": "Resume context: params, status, findings by group, models, log tail, report path.",
                    "parameters": {"type": "object", "properties": {**_TS, "log_tail": {"type": "integer"}}, "required": ["topic", "session"]}}

SHOP_UPDATE_PARAMS = {
    "name": "shop_update_params", "description": "Change brief fields / status (only given fields).",
    "parameters": {"type": "object", "properties": {
        **_TS, "status": {"type": "string", "enum": ["draft", "searching", "done"]},
        "query": {"type": "string"}, "purpose": {"type": "string"}, "must": _STR_LIST, "nice": _STR_LIST, "extra": _STR_LIST,
        "geo": _GEO, "budget_uah": {"type": "integer"}, "notes": {"type": "string"}, "sites": _STR_LIST,
        "category": {"type": "string", "description": "product category name as the sites call it (from the probe), e.g. Смартфони / Монітори"},
        "reviews": {"type": "string", "enum": ["none", "cards", "full"], "description": "review depth chosen via shop_menu(reviews)"},
        "mode": {"type": "string", "enum": ["exact", "spec", "reference"], "description": "search type chosen via shop_menu(mode)"},
        "condition": {"type": "string", "enum": ["new", "any"], "description": "chosen via shop_menu(condition); new = б/у/відновлений cards dropped"},
        "reference": {"type": "object", "description": "reference mode: result of shop_resolve (title, url, source, spec)"},
        "items": {"type": "array", "items": {"type": "object", "properties": {"name": {"type": "string"}, "must": _STR_LIST, "nice": _STR_LIST}, "required": ["name"]},
                  "description": "reference mode: the things to buy, each with its own must/nice (confirmed by the user)"},
        "shortlist": {**_STR_LIST, "description": "models picked in shop_menu(candidates) to compare in depth"},
    }, "required": ["topic", "session"]},
}

SHOP_ADD_FINDINGS = {"name": "shop_add_findings", "description": "Store findings (validated; same URL merges). Use for reviews and for sites without a fetcher.",
                     "parameters": {"type": "object", "properties": {**_TS, "findings": {"type": "array", "items": FINDING, "minItems": 1}}, "required": ["topic", "session", "findings"]}}

SHOP_LIST_FINDINGS = {"name": "shop_list_findings", "description": "Read findings, filter by group/model, trim with fields.",
                      "parameters": {"type": "object", "properties": {**_TS, "group": {"type": "string", "enum": ["marketplace", "aggregator", "review"]}, "model": {"type": "string"}, "fields": _STR_LIST}, "required": ["topic", "session"]}}

SHOP_LOG = {"name": "shop_log", "description": "Journal a step (source_done / source_blocked / next / note).",
            "parameters": {"type": "object", "properties": {**_TS, "event": {"type": "string"}, "detail": {}}, "required": ["topic", "session", "event"]}}

SHOP_SET_SUMMARY = {
    "name": "shop_set_summary", "description": "Store verdict, picks, caveats; mark done.",
    "parameters": {"type": "object", "properties": {
        **_TS,
        "picks": {"type": "array", "description": "best positions in rank order; each gets its own block in the report",
                  "items": {"type": "object", "properties": {"model": {"type": "string"}, "why": {"type": "string", "description": "1–2 sentences: why it fits the brief / purpose"}, "url": {"type": "string"},
                                                             "pros": _STR_LIST, "cons": _STR_LIST}, "required": ["model", "why"]}},
        "verdict": {"type": "string", "description": "comparison of the picks against each other + the final recommendation (markdown ok)"},
        "caveats": _STR_LIST, "status": {"type": "string", "enum": ["draft", "searching", "done"]},
    }, "required": ["topic", "session"]},
}

SHOP_RENDER_REPORT = {"name": "shop_render_report", "description": "Render report.md; returns path + row counts (markdown only with full=true). Show the file to the user with read_file.",
                      "parameters": {"type": "object", "properties": {**_TS, "full": {"type": "boolean"}}, "required": ["topic", "session"]}}

SHOP_ADD_FOLLOWUP = {"name": "shop_add_followup", "description": "Save a follow-up Q&A under the session and relink report.md.",
                     "parameters": {"type": "object", "properties": {**_TS, "title": {"type": "string"}, "question": {"type": "string"}, "answer_md": {"type": "string"}}, "required": ["topic", "session", "title", "question", "answer_md"]}}

SHOP_SOURCES = {"name": "shop_sources", "description": "Source catalogue (sites, fetch method, review query templates). query fills {q}/{model}.",
                "parameters": {"type": "object", "properties": {"group": {"type": "string", "enum": ["geo", "marketplaces", "aggregators", "reviews"]}, "query": {"type": "string"}}}}

SHOP_CANDIDATES = {
    "name": "shop_candidates",
    "description": ("Universal shortlist for ANY product category: searches hotline + e-katalog, keeps cards of `category`, "
                    "filters by `want` against each card's own characteristics line, dedupes by model, ranks by offers/reviews, "
                    "stores aggregator findings. Returns ≤40 candidates + `facets` (what parameters this category has, with ranges "
                    "and common values) + `dropped_by_spec`. Widens a too-narrow query automatically (see query_tried). "
                    "Use facets when the user does not know which parameters to ask for."),
    "parameters": {"type": "object", "properties": {
        **_TS, "query": {"type": "string", "description": "short product query in Ukrainian, e.g. 'монітор 27 OLED', 'інвертор 24V'"},
        "category": {"type": "string", "description": "aggregator category name from the probe (default: params.category)"},
        "want": {"type": "object", "description": ("constraints checked against the card's spec line; keys are matched loosely "
                                                   "('потужність' finds 'номінальна потужність'). Value forms: [min, max] or [min] = numeric range "
                                                   "in the value's own unit (3 кВт == 3000 Вт), a number = exact ±2%, a string or list of strings = substring. "
                                                   "Example: {\"потужність\": [2000, 3000], \"форма\": \"синус\", \"напруга\": 24}")},
        "strict": {"type": "boolean", "description": "also drop cards whose spec does not state a constrained parameter (default false: kept and listed in `unverified`)"},
        "pages": {"type": "integer", "description": "hotline pages (default 2, 48 cards each)"}},
        "required": ["topic", "session", "query"]},
}

SHOP_FETCH = {
    "name": "shop_fetch",
    "description": "Scripted site fetch for one model (script sites only, see enum). Stores matching offers; returns compact offers + rozetka review texts / hotline per-shop prices.",
    "parameters": {"type": "object", "properties": {
        **_TS, "site": {"type": "string", "enum": ["hotline", "ekatalog", "pn", "rozetka", "foxtrot", "moyo", "allo", "comfy", "citrus", "eldorado", "prom", "epicentr", "telemart", "brain"]},
        "model": {"type": "string"}, "geo": _GEO, "limit": {"type": "integer"},
        "category": {"type": "string", "description": "product category chosen from the probe (e.g. Смартфони); cards in other/accessory categories are dropped"},
    }, "required": ["topic", "session", "site", "model"]},
}

SHOP_PROBE = {
    "name": "shop_probe",
    "description": "Cheap parallel probe: one search per script site, returns hit counts + 3 sample titles per site (nothing stored, ~5 s). Use before choosing sources.",
    "parameters": {"type": "object", "properties": {
        "query": {"type": "string"}, "exclude": {**_STR_LIST, "description": "site keys to skip"}, "only": _STR_LIST,
    }, "required": ["query"]},
}

SHOP_MENU = {
    "name": "shop_menu",
    "description": "Interactive pick list rendered by the plugin in the host UI (arrows/numbers/checkboxes, one screen). kinds: topics | sessions(topic) | mode(query) | condition | probe (→ {probe:bool, only}) | sources(query, only?, probe?) | candidates(candidates) | reviews. Returns {values:[...], free_text, probe?}. On error no_ui → ask in chat with a numbered list.",
    "parameters": {"type": "object", "properties": {
        "kind": {"type": "string", "enum": ["topics", "sessions", "mode", "condition", "probe", "sources", "candidates", "reviews"]},
        "topic": _TOPIC, "query": {"type": "string", "description": "sources: run the probe with this query first"},
        "exclude": _STR_LIST, "only": {**_STR_LIST, "description": "sources: probe only these sites (from the probe menu)"},
        "probe": {"type": "boolean", "description": "sources: run the probe before listing (default true when query given)"},
        "candidates": {"type": "array", "items": {"type": "object"}, "description": "candidates: rows from shop_candidates"},
    }, "required": ["kind"]},
}

SHOP_RESOLVE = {
    "name": "shop_resolve",
    "description": "Reference mode: read the owned device from a product URL (rozetka …) or a model name (hotline) → {title, url, source, category_path, spec{}} for deriving what to buy. Store the result with shop_update_params(reference=…).",
    "parameters": {"type": "object", "properties": {"reference": {"type": "string", "description": "product URL or model name"}}, "required": ["reference"]},
}

SHOP_REVIEWS = {
    "name": "shop_reviews",
    "description": "Scripted buyer reviews for one model from its stored offers (rozetka, hotline, comfy, moyo, citrus, allo, prom, epicentr): parallel fetch, condensed to per-site rating stats + only informative sentences (≤2.5k chars). Stores one review finding per site. Raw texts never returned.",
    "parameters": {"type": "object", "properties": {**_TS, "model": {"type": "string"}, "sites": {**_STR_LIST, "description": "limit to these sites (default: all stored)"}},
                   "required": ["topic", "session", "model"]},
}

ALL = [SHOP_LIST_TOPICS, SHOP_CREATE_TOPIC, SHOP_LIST_SESSIONS, SHOP_CREATE_SESSION, SHOP_GET_SESSION,
       SHOP_UPDATE_PARAMS, SHOP_ADD_FINDINGS, SHOP_LIST_FINDINGS, SHOP_LOG, SHOP_SET_SUMMARY,
       SHOP_RENDER_REPORT, SHOP_ADD_FOLLOWUP, SHOP_SOURCES, SHOP_CANDIDATES, SHOP_FETCH, SHOP_PROBE, SHOP_MENU, SHOP_REVIEWS, SHOP_RESOLVE]
