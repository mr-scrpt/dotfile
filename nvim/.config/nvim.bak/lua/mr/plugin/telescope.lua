return {
	"nvim-telescope/telescope.nvim",
	branch = "0.1.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{
			"nvim-telescope/telescope-live-grep-args.nvim",
			version = "^1.0.0",
		},
		{ "nvim-telescope/telescope-ui-select.nvim" },
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")
		local builtin = require("telescope.builtin")

		require("telescope").load_extension("live_grep_args")

		telescope.setup({
			extensions = {
				["ui-select"] = {
					require("telescope.themes").get_dropdown(),
				},
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
					override_file_sorter = true,
					case_mode = "smart_case",
				},
			},
			defaults = {
				path_display = { "truncate " },
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
					"-i",
				},
				mappings = {
					i = {
						["<C-k>"] = actions.move_selection_previous, -- move to prev result
						["<C-j>"] = actions.move_selection_next, -- move to next result
						["<C-s>"] = actions.send_selected_to_qflist + actions.open_qflist, -- only selected to quickfix
						-- ["<C-q>"] = actions.smart_send_to_qflist, -- not work
						["<c-x>"] = actions.delete_buffer,
					},
					n = {
						["d"] = actions.delete_buffer,
					},
				},
			},
		})

		-- telescope.load_extension("fzf")
		pcall(require("telescope").load_extension, "fzf")
		pcall(require("telescope").load_extension, "ui-select")

		local opt = require("telescope.themes").get_ivy({
			sort_lastused = true,
		})

		local function theme_wrapper(telescope_command)
			return function()
				telescope_command(opt)
			end
		end
		-- set keymaps
		-- local keymap = vim.keymap -- for conciseness
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { desc = "Telescope: " .. desc })
		end
		-- keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Fuzzy find files in cwd" })
		-- keymap.set("n", "<leader>fw", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")
		-- keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, {})
		-- keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Fuzzy find recent files" })
		-- keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Fuzzy find recent files" })
		-- keymap.set("n", "<leader>fc", builtin.grep_string, { desc = "Find string under cursor in cwd" })
		map("<leader>sh", builtin.help_tags, "[S]earch [H]elp")
		map("<leader>sk", builtin.keymaps, "[S]earch [K]eymaps")

		map("<leader>sf", builtin.find_files, "[S]earch [F]iles")
		map("<leader>sw", builtin.grep_string, "[S]earch current [W]ord")
		map("<leader>ssc", builtin.lsp_document_symbols, "[S]earch [S]ymbols [C]urrent document")
		map("<leader>ssp", builtin.lsp_dynamic_workspace_symbols, "[S]earch [S]ymbols in [P]roject")
		map("<leader>sg", theme_wrapper(builtin.live_grep), "[S]earch by [G]rep")
		map("<leader>sd", builtin.diagnostics, "[S]earch [D]iagnostics")
		map("<leader>sr", builtin.resume, "[S]earch [R]esume")
		map("<leader>s.", builtin.oldfiles, '[S]earch Recent Files ("." for repeat)')
		map("<leader>sb", theme_wrapper(builtin.buffers), "[S] Find existing [B]uffers")
		map("<leader>/", builtin.current_buffer_fuzzy_find, "[/] Fuzzily search in current buffer")

		-- Slightly advanced example of overriding default behavior and theme
		-- vim.keymap.set("n", "<leader>/", function()
		-- 	-- You can pass additional configuration to telescope to change theme, layout, etc.
		-- 	builtin.current_buffer_fuzzy_find()
		-- end, { desc = "[/] Fuzzily search in current buffer" })
	end,
}
