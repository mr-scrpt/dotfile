return {
	"kdheepak/lazygit.nvim",
	-- optional for floating window border decoration
	dependencies = { "nvim-lua/plenary.nvim" },
	event = { "VeryLazy" },
	config = function()
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { desc = "LazyGit: " .. desc, silent = true })
		end
		map("<leader>lg", ":LazyGit<CR>", "[L]azy [G]it interface")
	end,
}
