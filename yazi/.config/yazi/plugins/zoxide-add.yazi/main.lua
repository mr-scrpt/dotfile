local function setup()
	ps.sub("cd", function()
		local cwd = cx.active.current.cwd
		if cwd then
			local path_str = tostring(cwd)
			
			-- 1. Показываем уведомление (для проверки)
			ya.notify({
				title = "Zoxide",
				content = "Adding: " .. path_str,
				timeout = 2.0,
				level = "info",
			})

			-- 2. Выполняем команду добавления
			-- Используем shell 'sh -c', это самый надежный способ
			Command("sh"):args({ "-c", "zoxide add " .. ya.quote(path_str) }):spawn()
		end
	end)
end

return { setup = setup }
