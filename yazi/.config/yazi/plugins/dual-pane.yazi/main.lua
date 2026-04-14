local M = {}

local function log(msg)
	local f = io.open("/tmp/yazi_dual_pane.log", "a")
	if f then
		f:write(os.date("%H:%M:%S") .. " - " .. tostring(msg) .. "\n")
		f:close()
	end
end

-- Мост для получения пути
local get_cwd = ya.sync(function(state)
	if cx.active and cx.active.current then
		return tostring(cx.active.current.cwd)
	end
	return ""
end)

-- НОВЫЙ МОСТ: Безопасное изменение пропорций колонок в главном потоке Yazi
local set_ratio = ya.sync(function(state, a, b, c)
	rt.mgr.ratio = { a, b, c }
end)

function M:entry()
	log("=== Вызов плагина ===")

	local cwd = get_cwd()
	if cwd == "" then
		return
	end

	-- Проверяем количество панелей Tmux
	os.execute("tmux display-message -p '#{window_panes}' > /tmp/yazi_tmux_panes 2>/dev/null")

	local f = io.open("/tmp/yazi_tmux_panes", "r")
	if not f then
		return
	end
	local count_str = f:read("*a")
	f:close()

	local pane_count = tonumber(count_str:match("%d+"))

	if pane_count == 1 then
		log("Сжимаем колонки в 1...")
		-- Меняем интерфейс текущей панели (Родитель: 0, Текущая: 1, Превью: 0)
		set_ratio(0, 1, 0)

		log("Открываем сплит...")
		local cmd = string.format("tmux split-window -h 'env YAZI_DUAL_PANE=1 yazi \"%s\"'", cwd)
		os.execute(cmd)
	elseif pane_count and pane_count >= 2 then
		log("Возвращаем 3 колонки...")
		-- Возвращаем классический вид (Родитель: 1, Текущая: 4, Превью: 3)
		-- Если в твоем yazi.toml другие пропорции, поменяй эти цифры на свои!
		set_ratio(1, 4, 3)

		log("Закрываем соседнюю панель...")
		os.execute("tmux kill-pane -t !")
	end
end

return M
