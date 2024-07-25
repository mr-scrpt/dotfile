return {
	"nvim-neo-tree/neo-tree.nvim",

	branch = "v3.x",
	dependencies = {
		-- "JoosepAlviste/nvim-ts-context-commentstring"
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
		{
			"s1n7ax/nvim-window-picker",
			--tag = "v1.*",
			config = function()
				require("window-picker").setup({
					autoselect_one = true,
					include_current = false,
					filter_rules = {
						-- filter using buffer options
						bo = {
							-- if the file type is one of following, the window will be ignored
							filetype = { "neo-tree", "neo-tree-popup", "notify" },

							-- if the buffer type is one of following, the window will be ignored
							buftype = { "terminal", "quickfix" },
						},
					},
					other_win_hl_color = "#e35e4f",
				})
			end,
		},
	},
	opts = {
		auto_expand_width = true,
		event_handlers = {
			event = "neo_tree_buffer_enter",
			handler = function()
				vim.opt_local.relativenumber = true
			end,
		},
	},

	config = function()
		local neotree = require("neo-tree")
		neotree.setup({
			popup_border_style = "rounded",
			-- enable_git_status = true,
			-- enable_diagnostics = true,
			sources = { "filesystem", "buffers", "git_status" },
			source_selector = {
				winbar = true,
				content_layout = "center",
				sources = {
					{ source = "filesystem" },
					{ source = "buffers" },
					{ source = "git_status" },
					-- { source = "document_symbols"},
				},
			},
			buffers = {
				follow_current_file = {
					enabled = true, -- This will find and focus the file in the active buffer every time
					--              -- the current file is changed while the tree is open.
					leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
				},
			},
			filesystem = {
				check_gitignore_in_search = false, -- Check gitignore status for files/directories when searching.
				find_by_full_path_words = false,
				-- Setting this to false will speed up searches, but gitignored
				-- items won't be marked if they are visible.
			},
			default_component_configs = {
				container = {
					enable_character_fade = true,
				},
				indent = {
					indent_size = 2,
					padding = 1, -- extra padding on left hand side
					-- indent guides
					with_markers = true,
					indent_marker = "│",
					last_indent_marker = "└",
					highlight = "NeoTreeIndentMarker",
					-- expander config, needed for nesting files
					with_expanders = nil, -- if nil and file nesting is enabled, will enable expanders
					expander_collapsed = "",
					expander_expanded = "",
					expander_highlight = "NeoTreeExpander",
				},
				icon = {
					folder_closed = "",
					folder_open = "",
					folder_empty = "󰜌",
					-- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
					-- then these will never be used.
					default = "*",
					highlight = "NeoTreeFileIcon",
				},
				modified = {
					symbol = "[+]",
					highlight = "NeoTreeModified",
				},
				name = {
					trailing_slash = false,
					use_git_status_colors = true,
					highlight = "NeoTreeFileName",
				},
				git_status = {
					symbols = {
						-- Change type
						added = "󰎔 ", -- or "✚", but this is redundant info if you use git_status_colors on the name
						modified = "󰚰 ", -- or "", but this is redundant info if you use git_status_colors on the name
						deleted = "󱘄 ", -- this can only be used in the git_status source
						renamed = "󰑕 ", -- this can only be used in the git_status source
						-- Status type
						untracked = " ",
						ignored = " ",
						unstaged = " ",
						staged = "",
						conflict = "",
					},
				},
				-- If you don't want to use these columns, you can set `enabled = false` for each of them individually
				file_size = {
					enabled = true,
					required_width = 64, -- min width of window required to show this column
				},
				type = {
					enabled = true,
					required_width = 122, -- min width of window required to show this column
				},
				last_modified = {
					enabled = true,
					required_width = 88, -- min width of window required to show this column
				},
				created = {
					enabled = true,
					required_width = 110, -- min width of window required to show this column
				},
				symlink_target = {
					enabled = false,
				},
			},
		})
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { desc = "NeoTree: " .. desc })
		end
		map("<leader>e", ":Neotree float reveal<CR>", "NeoTree [E]xplore")
		map("<leader>E", ":Neotree right reveal<CR>", "NeoTree [E]xplore Right")
		map("<leader>o", ":Neotree float git_status<CR>", "NeoTree [O]pen Git Status")
		-- keymap.set("n", "<leader>e", ":Neotree float reveal<CR>")
		-- keymap.set("n", "<leader>E", ":Neotree right reveal<CR>")
		-- keymap.set("n", "<leader>o", ":Neotree float git_status<CR>")
	end,
}
--vim.keymap.set("n", "<leader>e", ":Neotree float reveal<CR>")
--vim.keymap.set("n", "<leader>E", ":Neotree right reveal<CR>")
--vim.keymap.set("n", "<leader>o", ":Neotree float git_status<CR>")
