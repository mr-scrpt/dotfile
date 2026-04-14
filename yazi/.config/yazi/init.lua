--  yazi/.config/yazi/init.lua
require("folder-rules"):setup()
require("zoxide"):setup({
	update_db = true,
})
require("session"):setup({ sync_yanked = true })

-- --- Инициализация Dual-Pane режима ---
if os.getenv("YAZI_DUAL_PANE") == "1" then
	-- Напрямую меняем runtime-переменную пропорций интерфейса при старте
	rt.mgr.ratio = { 0, 1, 0 }
end
