return {
	"orlp/vim-bunlink",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		-- import nvim-autopairs
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { desc = "Bunlink: " .. desc })
		end

		map("<leader>qc", ":Bunlink<CR>", "[Q]uick [C]urrent without close panel")

		-- configure autopairs
	end,
}
