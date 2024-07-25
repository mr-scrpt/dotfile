return {
	"Exafunction/codeium.vim",
	config = function()
		-- Change '<C-g>' here to any keycode you like.
		--
		local map = function(keys, func, desc)
			vim.keymap.set("i", keys, func, { expr = true, silent = true, desc = "CODEIUM: " .. desc })
		end

		-- map("<A-CR>", function()
		-- 	return vim.fn["codeium#Accept"]()
		-- end, "[Enter] Accept")

		map("<C-k>", function()
			return vim.fn["codeium#CycleCompletions"](1)
		end, "[F] Next completion")

		map("<C-j>", function()
			return vim.fn["codeium#CycleCompletions"](-1)
		end, "[S] Previous completion")

		map("<C-x>", function()
			return vim.fn["codeium#Clear"]()
		end, "[X] Clear")
	end,
}
