return {
	"NvChad/nvterm",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local terminal = require("nvterm")
		local term = require("nvterm.terminal")
		terminal.setup({
			terminals = {
				shell = vim.o.shell,
				list = {},
				type_opts = {
					float = {
						relative = "editor",
						row = 0.2,
						col = 0.2,
						width = 0.6,
						height = 0.5,
						border = "single",
					},
					horizontal = { location = "rightbelow", split_ratio = 0.6, border = "single" },
					vertical = { location = "rightbelow", split_ratio = 0.5, border = "single" },
				},
			},
			behavior = {
				autoclose_on_quit = {
					enabled = false,
					confirm = true,
				},
				close_on_exit = true,
				auto_insert = true,
			},
		})

		local map = function(keys, func, desc, mode)
			mode = mode or { "n", "t" }
			vim.keymap.set(mode, keys, func, { desc = "NvTerm: " .. desc })
		end

		map("<leader>tv", function()
			term.toggle("vertical")
		end, "[T]erminal [V]ertical")

		map("<leader>th", function()
			term.toggle("horizontal")
		end, "[T]erminal [H]orizontal")

		map("<leader>tf", function()
			term.toggle("float")
		end, "[T]erminal [F]loat")

		map("<C-x>", vim.api.nvim_replace_termcodes("<C-\\><C-N>", true, true, true), "[X] Terminal close")
	end,
}
