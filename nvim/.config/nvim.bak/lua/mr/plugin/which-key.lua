return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 500
	end,
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
	},
	config = function()
		local wk = require("which-key")
		wk.add({
			-- Группа "Find"
			{ "<leader>f", group = "Find" },
			{ "<leader>ff", desc = "Find File" },
			{ "<leader>fb", desc = "Find Buffer" },
			{ "<leader>fh", desc = "Find Help" },
			{ "<leader>fw", desc = "Find Text" },

			-- Команды вне групп
			{ "<leader>e", desc = "File Manager" },
			{ "<leader>o", desc = "Git status" },
			{ "<leader>x", desc = "Close Buffer" },
			{ "<leader>w", "<cmd>w<cr>", desc = "Save" },

			-- Группа "Terminal"
			{ "<leader>t", group = "Terminal" },
			{ "<leader>tf", desc = "Float terminal" },
			{ "<leader>th", desc = "Horizontal terminal" },

			-- Без подсветки
			{ "<leader>h", desc = "No highlight" },

			-- Группа "Git"
			{ "<leader>g", group = "Git" },
			{ "<leader>gb", desc = "Branches" },
			{ "<leader>gc", desc = "Commits" },
			{ "<leader>gs", desc = "Status" },

			-- Группа "Comment"
			{ "<leader>c", group = "Comment" },
			{ "<leader>cl", desc = "Comment Line" },

			-- Группа "LSP"
			{ "<leader>l", group = "LSP" },
			{ "<leader>ld", desc = "Diagnostic" },
			{ "<leader>lD", desc = "Hover diagnostic" },
			{ "<leader>lf", desc = "Format" },
			{ "<leader>lr", desc = "Rename" },
			{ "<leader>la", desc = "Action" },
			{ "<leader>ls", desc = "Symbol" },
		})

		-- wk.register({
		-- 	f = {
		-- 		name = "Find",
		-- 		f = { "Find File" },
		-- 		b = { "Find Buffer" },
		-- 		h = { "Find Help" },
		-- 		w = { "Find Text" },
		-- 	},
		-- 	e = { "File Manager" },
		-- 	o = { "Git status" },
		-- 	x = { "Close Buffer" },
		-- 	w = { "Save" },
		-- 	t = { name = "Terminal", f = { "Float terminal" }, h = { "Horizontal terminal" } },
		-- 	h = { "No highlight" },
		-- 	g = { name = "Git", b = "Branches", c = "Commits", s = "Status" },
		-- 	c = { name = "Comment", l = "Comment Line" },
		-- 	l = {
		-- 		name = "LSP",
		-- 		d = "Diagnostic",
		-- 		D = "Hover diagnostic",
		-- 		f = "Format",
		-- 		r = "Rename",
		-- 		a = "Action",
		-- 		s = "Symbol",
		-- 	},
		-- }, { prefix = "<leader>" })
	end,
}
