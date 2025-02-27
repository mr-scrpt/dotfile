return {
	"crnvl96/lazydocker.nvim",
	event = "VeryLazy",
	opts = {}, -- automatically calls `require("lazydocker").setup()`
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	config = function()
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { desc = "LazyDocker: " .. desc, silent = true })
		end
		map("<leader>ld", ":LazyDocker<CR>", "[L]azy [D]ocker interface")
	end,
}
