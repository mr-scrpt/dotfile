--  yazi/.config/yazi/init.lua
require("folder-rules"):setup()
require("zoxide"):setup({
	update_db = true,
})
require("session"):setup({ sync_yanked = true })
