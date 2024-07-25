return {
	"ton/vim-bufsurf",
	-- event = { "BufReadPre", "BufNewFile" },
	config = function()
		-- import nvim-autopairs
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { desc = "BufSurf: " .. desc })
		end

		map("bp", ":BufSurfBack<CR>", "[B]uffer go to [P]rev")
		map("bn", ":BufSurfForward<CR>", "[B]uffer go to [N]ext")

		-- configure autopairs
	end,
}
