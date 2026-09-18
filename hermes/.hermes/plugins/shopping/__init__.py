"""Shopping plugin — registration only: shop_* tools, /shop slash command.

The workflow skill lives in the dotfile stow package next to this plugin and is linked into
~/.hermes/skills/research/shopping-research/ (so it appears in the <available_skills> index);
it is not bundled here to avoid a second, read-only copy under the plugin namespace.
"""
from __future__ import annotations

from . import schemas, tools


def register(ctx):
    for schema in schemas.ALL:
        ctx.register_tool(name=schema["name"], toolset="shopping", schema=schema,
                          handler=tools.HANDLERS[schema["name"]], emoji="🛒")
    ctx.register_command("shop", tools.make_slash_shop(lambda text: ctx.inject_message(text, role="user")),
                         description="Shopping research: /shop = start guided search; /shop status [topic] [session]",
                         args_hint="[status] [topic] [session]")
