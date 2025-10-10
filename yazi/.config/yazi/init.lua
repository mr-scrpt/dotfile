require("git"):setup({ order = 0 })

require("full-border"):setup()

require("starship"):setup()

require("session"):setup({
	sync_yanked = true,
})

require("folder-rules"):setup()

-- Добавили новый плагин для тегов
require("simple-tag"):setup()
