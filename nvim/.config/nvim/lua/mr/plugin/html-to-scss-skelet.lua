return {
	dir = "~/Project/solution/nvim/plugins/html-to-scss-skelet.nvim",
	dev = true,
	config = function()
		vim.api.nvim_set_keymap(
			"v",
			"<leader>ms",
			":lua require('html_to_scss_skelet').html_to_scss()<CR>",
			{ noremap = true, silent = true }
		)
	end,
	lazy = false,
}
-- return {
-- 	"mr-scrpt/html-to-scss-skelet.nvim",
-- 	config = function()
-- 		vim.api.nvim_set_keymap(
-- 			"v",
-- 			"<leader>ms",
-- 			":lua require('html_to_scss_skelet').html_to_scss()<CR>",
-- 			{ noremap = true, silent = true }
-- 		)
-- 	end,
-- }
