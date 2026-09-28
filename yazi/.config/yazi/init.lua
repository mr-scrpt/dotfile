require("folder-rules"):setup()

-- Feed every visited directory into zoxide (built-in plugin), so `Z` and the
-- shell's `z` learn from yazi too.
require("zoxide"):setup({ update_db = true })

-- Share the yank buffer between yazi instances (built-in plugin).
require("session"):setup({ sync_yanked = true })

-- Dual pane (split-tabs.yazi) on startup only where the launcher asks for it:
-- the bottom widget runs `env YAZI_DUAL_PANE=1 yazi`. Plain `yazi` stays single-pane
-- and can still switch with <C-s>.
if os.getenv("YAZI_DUAL_PANE") == "1" then
	ya.emit("plugin", { "split-tabs", "spl_activate" })
	ya.emit("plugin", { "split-tabs", "spl_preview" })
end
