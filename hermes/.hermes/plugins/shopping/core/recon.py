"""Layer 2 — recon: the contract for the topic-research step.

Before any search runs, someone has to understand WHAT the user asked for: how the market spells
the thing ("Mini LED" vs "MiniLED" vs nothing at all), which variants of the technology exist,
which measurable parameters separate a good one from a bad one (dimming zones, peak brightness),
and what the aggregators simply do not print. That is judgement work — a subagent does it with
web search and source samples — but its ANSWER must be machine-checkable, or the pipeline cannot
rely on it.

This module owns that contract: the schema the subagent must return, the prompt describing the
job, and `validate()` which the plugin runs before the result is allowed into the session.
"""
from __future__ import annotations

from .fs import err

SCHEMA = {
    "type": "object",
    "required": ["terms", "criteria"],
    "properties": {
        "terms": {"type": "array", "description": "every spelling the sites use for what the user asked "
                                                  "(e.g. ['Mini LED', 'MiniLED', 'Mini-LED', 'міні-лед'])",
                  "items": {"type": "string"}},
        "variants": {"type": "array", "description": "kinds inside the technology and how they differ",
                     "items": {"type": "object", "required": ["name", "note"],
                               "properties": {"name": {"type": "string"}, "note": {"type": "string"},
                                              "terms": {"type": "array", "items": {"type": "string"}}}}},
        "quality": {"type": "array", "description": "measurable parameters that separate good from bad INSIDE "
                                                    "the chosen technology, with the direction that is better",
                    "items": {"type": "object", "required": ["key", "better"],
                              "properties": {"key": {"type": "string"},
                                             "better": {"type": "string", "enum": ["higher", "lower", "value"]},
                                             "unit": {"type": "string"}, "note": {"type": "string"},
                                             "printed_by": {"type": "array", "items": {"type": "string"},
                                                            "description": "sources that actually print it"}}}},
        "criteria": {"type": "array", "description": "ready criteria for shop_candidates (core.spec format, "
                                                     "either-groups for alternatives, units as the sites write them)",
                     "items": {"type": "object"}},
        "queries": {"type": "array", "description": "one short site query per alternative the user allows",
                    "items": {"type": "string"}},
        "unknowns": {"type": "array", "description": "facts no aggregator prints — check these in reviews/специфике",
                     "items": {"type": "string"}},
        "notes": {"type": "string"},
    },
}

PROMPT = """Ты — этап РАЗВЕДКИ в конвейере поиска товаров (плагин shopping, Украина).

Запрос пользователя: {query}
Назначение: {purpose}
Слова пользователя о параметрах: {wanted}
Источники, где будем искать: {sites}

Задача: понять предметную область ДО поиска, чтобы поиск не промахнулся. Ты НЕ ищешь товары и
НЕ выбираешь модели — ты выясняешь, как устроена категория и как её искать.

Сделай:
1. Выясни, как площадки называют то, что просит пользователь. Обязательно проверь фактически:
   `shop_source_plan(action="sample", site=<site>, query=<вариант>)` на 2–3 источниках. Смотри
   `observed` — в каком КЛЮЧЕ и какими СЛОВАМИ это написано (например у ek.ua «Матриця: Mini LED
   IPS», а hotline слово Mini LED не пишет вовсе).
2. Если пользователь назвал технологию/стандарт — выясни её разновидности и чем они отличаются
   (web_search + обзоры). Никогда не заявляй, что чего-то «нет на рынке», не проверив выборкой.
3. Определи измеримые параметры качества ВНУТРИ технологии: чем хороший экземпляр отличается от
   плохого (зоны затемнения, пиковая яркость, тип панели…). Для каждого укажи, где он печатается,
   а если нигде — вынеси в `unknowns`, это будем смотреть в отзывах и обзорах.
4. Составь `criteria` в формате движка: {{"key", "any_of":[{{"min","max","unit"}}], "contains":[...],
   "label", "either":[...]}}. Единицы — КАК ПИШУТ САЙТЫ (видел «3 кBт» — пиши «кBт»). Альтернативы
   («OLED или Mini-LED») — одной группой `either`, а не двумя поисками. Если сайт не печатает
   параметр, но есть косвенный признак (яркость 1000+ нит как признак Mini-LED) — добавь его
   веткой с пометкой в label, что это прокси.
5. Составь `queries`: по одному короткому запросу на каждую альтернативу (сайты ищут по «И»,
   длинные запросы дают ноль).

Ответ — СТРОГО JSON по схеме, без markdown-обёртки. Русский язык в пояснениях."""


def validate(payload) -> dict:
    """Machine-check the subagent's answer before it enters the session."""
    if not isinstance(payload, dict):
        return err("recon: ответ должен быть JSON-объектом")
    terms = payload.get("terms")
    criteria = payload.get("criteria")
    if not isinstance(terms, list) or not terms or not all(isinstance(t, str) and t.strip() for t in terms):
        return err("recon: `terms` должен быть непустым списком строк (как площадки называют товар)")
    if not isinstance(criteria, list) or not criteria:
        return err("recon: `criteria` должен быть непустым списком критериев (формат core.spec)")
    for c in criteria:
        if not isinstance(c, dict):
            return err("recon: каждый критерий — объект")
        if not (c.get("key") or c.get("either")):
            return err(f"recon: критерий без `key` и без `either`: {str(c)[:80]}")
        if c.get("either") and not isinstance(c["either"], list):
            return err("recon: `either` должен быть списком критериев")
    for q in payload.get("quality") or []:
        if not isinstance(q, dict) or not q.get("key") or q.get("better") not in ("higher", "lower", "value"):
            return err(f"recon: параметр качества без key/better: {str(q)[:80]}")
    return {"success": True, "recon": {
        "terms": [t.strip() for t in terms],
        "variants": payload.get("variants") or [],
        "quality": payload.get("quality") or [],
        "criteria": criteria,
        "queries": [q for q in (payload.get("queries") or []) if isinstance(q, str) and q.strip()],
        "unknowns": payload.get("unknowns") or [],
        "notes": payload.get("notes") or "",
    }}


def brief(params: dict, sites: list[str] | None = None) -> dict:
    """Everything the recon subagent needs: the prompt, the schema, and how to run it."""
    wanted = "; ".join((params.get("must") or []) + (params.get("nice") or [])) or "не указаны"
    return {"success": True,
            "prompt": PROMPT.format(query=params.get("query", ""), purpose=params.get("purpose", ""),
                                    wanted=wanted, sites=", ".join(sites or params.get("sites") or []) or "ещё не выбраны"),
            "output_schema": SCHEMA,
            "how": "delegate_task(goal=prompt, output_schema=output_schema); затем shop_recon(action='store', "
                   "payload=<ответ подагента>) — плагин проверит контракт и положит criteria/queries в сессию"}
