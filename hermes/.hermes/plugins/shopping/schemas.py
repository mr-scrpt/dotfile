"""Tool schemas for the shopping plugin (what the model sees)."""

_TOPIC = {"type": "string", "description": "Topic slug, e.g. 'monitor' (from shop_list_topics)."}
_SESSION = {"type": "string", "description": "Session id, e.g. '2026-09-18_oled-27' (from shop_list_sessions)."}
_GEO = {"type": "string", "enum": ["ua_local", "ua_delivery"],
        "description": "ua_local = only stock in Ukraine (default); ua_delivery = also items shipped to Ukraine (Rozetka EU etc.)."}
_STR_LIST = {"type": "array", "items": {"type": "string"}}

FINDING = {
    "type": "object",
    "description": "One product/offer/review record. url is the dedup key.",
    "properties": {
        "group": {"type": "string", "enum": ["marketplace", "shop", "aggregator", "review"],
                  "description": "marketplace = rozetka/comfy/citrus/allo/foxtrot/eldorado/moyo/prom; shop = other retailers; aggregator = hotline/ek.ua/price.ua/pn.com.ua card; review = a review/forum/video page about one exact model."},
        "source": {"type": "string", "description": "Site key or name: rozetka, hotline, rtings, reddit …"},
        "title": {"type": "string", "description": "Product title as shown on the page."},
        "model": {"type": "string", "description": "Exact manufacturer model code, e.g. 'LG 27GS95QE-B'. Same code across findings links reviews to offers."},
        "url": {"type": "string"},
        "price_uah": {"type": "integer", "description": "Current price in UAH (single offer)."},
        "price_min_uah": {"type": "integer", "description": "Aggregator: lowest price."},
        "price_max_uah": {"type": "integer", "description": "Aggregator: highest price."},
        "price_note": {"type": "string", "description": "e.g. 'акция до 20.09', 'цена продавца X'."},
        "rating": {"type": "number", "description": "Rating on the page, 0-5."},
        "rating_count": {"type": "integer", "description": "Number of reviews/ratings on the page."},
        "offers_count": {"type": "integer", "description": "Aggregator: number of shops."},
        "availability": {"type": "string", "description": "'в наличии', 'под заказ', 'нет' …"},
        "seller": {"type": "string", "description": "Who sells: 'Rozetka', 'Rozetka EU', 'продавец Foo (marketplace)' …"},
        "delivery_scope": _GEO,
        "installment": {"type": "boolean", "description": "Installment / 'оплата частями' available."},
        "installment_note": {"type": "string", "description": "e.g. 'Моно 10 платежей, Приват 6'."},
        "pros": _STR_LIST,
        "cons": _STR_LIST,
        "nuances": {**_STR_LIST, "description": "Concrete issues users report for THIS model: 'скрипит пластик', 'засветы по углам', 'coil whine' …"},
        "review_sources": {**_STR_LIST, "description": "URLs of reviews this record's nuances came from."},
        "notes": {"type": "string"},
        "model_match": {"type": "string", "enum": ["exact", "probable", "unclear"],
                        "description": "For reviews: does the source name exactly this model code?"},
    },
    "required": ["group", "url"],
}

SHOP_LIST_TOPICS = {
    "name": "shop_list_topics",
    "description": "List shopping research topics (folders under ~/shopping) with session counts. Call first when the user wants to search for something to buy.",
    "parameters": {"type": "object", "properties": {}},
}

SHOP_CREATE_TOPIC = {
    "name": "shop_create_topic",
    "description": "Create a new topic folder (idempotent).",
    "parameters": {"type": "object", "properties": {
        "slug": {"type": "string", "description": "lowercase [a-z0-9-], e.g. 'monitor'"},
        "title": {"type": "string", "description": "Human title, e.g. 'Мониторы'"},
    }, "required": ["slug"]},
}

SHOP_LIST_SESSIONS = {
    "name": "shop_list_sessions",
    "description": "List dated search sessions inside a topic with status, query, findings count — use to offer 'continue which one?'.",
    "parameters": {"type": "object", "properties": {"topic": _TOPIC}, "required": ["topic"]},
}

SHOP_CREATE_SESSION = {
    "name": "shop_create_session",
    "description": "Start a new dated search session with the brief. Creates <topic>/<YYYY-MM-DD_slug>/ with search.json, findings.jsonl, log.jsonl.",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC,
        "query": {"type": "string", "description": "What we search, e.g. 'монитор 27\" OLED 100+ Гц'"},
        "must": {**_STR_LIST, "description": "Hard requirements."},
        "nice": {**_STR_LIST, "description": "Nice-to-have."},
        "extra": {**_STR_LIST, "description": "Extra conditions: 'оплата частями', 'гарантия 3 года' …"},
        "geo": _GEO,
        "budget_uah": {"type": "integer"},
        "notes": {"type": "string"},
        "slug": {"type": "string", "description": "Optional short slug for the folder name; derived from query if omitted."},
    }, "required": ["topic", "query"]},
}

SHOP_GET_SESSION = {
    "name": "shop_get_session",
    "description": "Full resume context for a session: params, status, summary, findings counts by group, known models, last log entries, follow-ups, report path.",
    "parameters": {"type": "object", "properties": {"topic": _TOPIC, "session": _SESSION,
                                                    "log_tail": {"type": "integer", "default": 15}},
                   "required": ["topic", "session"]},
}

SHOP_UPDATE_PARAMS = {
    "name": "shop_update_params",
    "description": "Update brief fields and/or status of a session (only provided fields change).",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC, "session": _SESSION,
        "status": {"type": "string", "enum": ["draft", "searching", "done"]},
        "query": {"type": "string"}, "must": _STR_LIST, "nice": _STR_LIST, "extra": _STR_LIST,
        "geo": _GEO, "budget_uah": {"type": "integer"}, "notes": {"type": "string"},
    }, "required": ["topic", "session"]},
}

SHOP_ADD_FINDINGS = {
    "name": "shop_add_findings",
    "description": "Append product/offer/review findings to the session (validated, deduped by URL — same URL merges fields and unions lists). Call after every source you scrape so progress survives.",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC, "session": _SESSION,
        "findings": {"type": "array", "items": FINDING, "minItems": 1},
    }, "required": ["topic", "session", "findings"]},
}

SHOP_LIST_FINDINGS = {
    "name": "shop_list_findings",
    "description": "Read findings, optionally filtered by group or model; 'fields' trims output.",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC, "session": _SESSION,
        "group": {"type": "string", "enum": ["marketplace", "shop", "aggregator", "review"]},
        "model": {"type": "string"},
        "fields": _STR_LIST,
    }, "required": ["topic", "session"]},
}

SHOP_LOG = {
    "name": "shop_log",
    "description": "Append a step to the session journal (which sources done, which blocked, what is next) so a resumed session knows where it stopped.",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC, "session": _SESSION,
        "event": {"type": "string", "description": "short id: 'source_done', 'source_blocked', 'next', 'note'"},
        "detail": {"description": "free-form string or object"},
    }, "required": ["topic", "session", "event"]},
}

SHOP_SET_SUMMARY = {
    "name": "shop_set_summary",
    "description": "Store the verdict / picks / caveats for the report and mark status (default done).",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC, "session": _SESSION,
        "verdict": {"type": "string", "description": "2-5 sentences in Russian."},
        "picks": {"type": "array", "items": {"type": "object", "properties": {
            "model": {"type": "string"}, "why": {"type": "string"}, "url": {"type": "string"}}, "required": ["model", "why"]}},
        "caveats": _STR_LIST,
        "status": {"type": "string", "enum": ["draft", "searching", "done"]},
    }, "required": ["topic", "session"]},
}

SHOP_RENDER_REPORT = {
    "name": "shop_render_report",
    "description": "Render report.md from findings + summary + follow-ups (two tables: marketplaces / shops, aggregator links, review nuances per model). Returns the markdown to show the user.",
    "parameters": {"type": "object", "properties": {"topic": _TOPIC, "session": _SESSION}, "required": ["topic", "session"]},
}

SHOP_ADD_FOLLOWUP = {
    "name": "shop_add_followup",
    "description": "Save a follow-up question + answer as followups/NN_slug.md and link it from report.md.",
    "parameters": {"type": "object", "properties": {
        "topic": _TOPIC, "session": _SESSION,
        "title": {"type": "string"}, "question": {"type": "string"},
        "answer_md": {"type": "string", "description": "Answer in markdown (Russian)."},
    }, "required": ["topic", "session", "title", "question", "answer_md"]},
}

SHOP_SOURCES = {
    "name": "shop_sources",
    "description": "Source catalogue (~/shopping/.config/sources.yaml): marketplaces, shops, aggregators, review sites with search URL templates, fetch method (browser vs plain) and geo/delivery markers. Pass query to get ready-to-open URLs.",
    "parameters": {"type": "object", "properties": {
        "group": {"type": "string", "enum": ["geo", "marketplaces", "shops", "aggregators", "reviews"]},
        "query": {"type": "string", "description": "Fills {q}/{model} in URL templates."},
    }},
}

ALL = [SHOP_LIST_TOPICS, SHOP_CREATE_TOPIC, SHOP_LIST_SESSIONS, SHOP_CREATE_SESSION, SHOP_GET_SESSION,
       SHOP_UPDATE_PARAMS, SHOP_ADD_FINDINGS, SHOP_LIST_FINDINGS, SHOP_LOG, SHOP_SET_SUMMARY,
       SHOP_RENDER_REPORT, SHOP_ADD_FOLLOWUP, SHOP_SOURCES]
