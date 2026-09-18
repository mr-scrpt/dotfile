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
        "group": {"type": "string", "enum": ["marketplace", "shop", "aggregator", "review"]},
        "source": {"type": "string", "description": "site key: rozetka, hotline, rtings, reddit…"},
        "title": {"type": "string"},
        "model": {"type": "string", "description": "exact model code; links reviews to offers"},
        "url": {"type": "string", "description": "dedup key"},
        "price_uah": {"type": "integer"}, "price_min_uah": {"type": "integer"}, "price_max_uah": {"type": "integer"},
        "price_note": {"type": "string"},
        "rating": {"type": "number"}, "rating_count": {"type": "integer"}, "offers_count": {"type": "integer"},
        "availability": {"type": "string"}, "seller": {"type": "string"}, "delivery_scope": _GEO,
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
    }, "required": ["topic", "query", "purpose"]},
}

SHOP_GET_SESSION = {"name": "shop_get_session", "description": "Resume context: params, status, findings by group, models, log tail, report path.",
                    "parameters": {"type": "object", "properties": {**_TS, "log_tail": {"type": "integer"}}, "required": ["topic", "session"]}}

SHOP_UPDATE_PARAMS = {
    "name": "shop_update_params", "description": "Change brief fields / status (only given fields).",
    "parameters": {"type": "object", "properties": {
        **_TS, "status": {"type": "string", "enum": ["draft", "searching", "done"]},
        "query": {"type": "string"}, "purpose": {"type": "string"}, "must": _STR_LIST, "nice": _STR_LIST, "extra": _STR_LIST,
        "geo": _GEO, "budget_uah": {"type": "integer"}, "notes": {"type": "string"},
    }, "required": ["topic", "session"]},
}

SHOP_ADD_FINDINGS = {"name": "shop_add_findings", "description": "Store findings (validated; same URL merges). Use for reviews and for sites without a fetcher.",
                     "parameters": {"type": "object", "properties": {**_TS, "findings": {"type": "array", "items": FINDING, "minItems": 1}}, "required": ["topic", "session", "findings"]}}

SHOP_LIST_FINDINGS = {"name": "shop_list_findings", "description": "Read findings, filter by group/model, trim with fields.",
                      "parameters": {"type": "object", "properties": {**_TS, "group": {"type": "string", "enum": ["marketplace", "shop", "aggregator", "review"]}, "model": {"type": "string"}, "fields": _STR_LIST}, "required": ["topic", "session"]}}

SHOP_LOG = {"name": "shop_log", "description": "Journal a step (source_done / source_blocked / next / note).",
            "parameters": {"type": "object", "properties": {**_TS, "event": {"type": "string"}, "detail": {}}, "required": ["topic", "session", "event"]}}

SHOP_SET_SUMMARY = {
    "name": "shop_set_summary", "description": "Store verdict, picks, caveats; mark done.",
    "parameters": {"type": "object", "properties": {
        **_TS, "verdict": {"type": "string"},
        "picks": {"type": "array", "items": {"type": "object", "properties": {"model": {"type": "string"}, "why": {"type": "string"}, "url": {"type": "string"}}, "required": ["model", "why"]}},
        "caveats": _STR_LIST, "status": {"type": "string", "enum": ["draft", "searching", "done"]},
    }, "required": ["topic", "session"]},
}

SHOP_RENDER_REPORT = {"name": "shop_render_report", "description": "Render report.md; returns the markdown to show the user verbatim.",
                      "parameters": {"type": "object", "properties": _TS, "required": ["topic", "session"]}}

SHOP_ADD_FOLLOWUP = {"name": "shop_add_followup", "description": "Save a follow-up Q&A under the session and relink report.md.",
                     "parameters": {"type": "object", "properties": {**_TS, "title": {"type": "string"}, "question": {"type": "string"}, "answer_md": {"type": "string"}}, "required": ["topic", "session", "title", "question", "answer_md"]}}

SHOP_SOURCES = {"name": "shop_sources", "description": "Source catalogue (sites, fetch method, hotline filter ids, review query templates). query fills {q}/{model}.",
                "parameters": {"type": "object", "properties": {"group": {"type": "string", "enum": ["geo", "marketplaces", "shops", "aggregators", "reviews", "hotline_filters"]}, "query": {"type": "string"}}}}

SHOP_CATALOG = {
    "name": "shop_catalog",
    "description": "Scripted hotline category walk: filter ids from shop_sources(hotline_filters) → candidate models matching want; stores aggregator findings.",
    "parameters": {"type": "object", "properties": {
        **_TS, "section": {"type": "string", "description": "e.g. computer/monitory"},
        "filter_ids": {"type": "array", "items": {"type": "integer"}},
        "want": {"type": "object", "description": "hard spec: {diagonal_in:[lo,hi], panel_any:[..], resolution:'2560x1440', refresh_min:100}"},
        "max_pages": {"type": "integer"},
    }, "required": ["topic", "session", "section", "filter_ids"]},
}

SHOP_FETCH = {
    "name": "shop_fetch",
    "description": "Scripted site fetch for one model (sites: hotline, rozetka, foxtrot, moyo, allo). Stores matching offers; returns compact offers + rozetka review texts / hotline per-shop prices.",
    "parameters": {"type": "object", "properties": {
        **_TS, "site": {"type": "string", "enum": ["hotline", "rozetka", "foxtrot", "moyo", "allo"]},
        "model": {"type": "string"}, "geo": _GEO, "limit": {"type": "integer"},
    }, "required": ["topic", "session", "site", "model"]},
}

ALL = [SHOP_LIST_TOPICS, SHOP_CREATE_TOPIC, SHOP_LIST_SESSIONS, SHOP_CREATE_SESSION, SHOP_GET_SESSION,
       SHOP_UPDATE_PARAMS, SHOP_ADD_FINDINGS, SHOP_LIST_FINDINGS, SHOP_LOG, SHOP_SET_SUMMARY,
       SHOP_RENDER_REPORT, SHOP_ADD_FOLLOWUP, SHOP_SOURCES, SHOP_CATALOG, SHOP_FETCH]
