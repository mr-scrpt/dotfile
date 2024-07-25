return {
	"ThePrimeagen/harpoon",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		local mark = require("harpoon.mark")
		local ui = require("harpoon.ui")
		-- set keymaps
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { desc = "Harpoon: " .. desc })
		end
		map("<leader>ha", mark.add_file, "[H]arpoon [A]dd")
		map("<leader>hl", ui.toggle_quick_menu, "[H]arpoon [L]ist")
	end,
}
