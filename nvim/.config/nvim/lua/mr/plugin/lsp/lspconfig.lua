return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},
	config = function()
		-- import lspconfig plugin
		local lspconfig = require("lspconfig")

		-- import cmp-nvim-lsp plugin
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

		-- local opts = { noremap = true, silent = true }
		local on_attach = function(_, bufnr)
			-- opts.buffer = bufnr

			local map = function(keys, func, desc)
				vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
			end

			-- set keybinds
			-- opts.desc = "Show LSP references"
			-- keymap.set("n", "dc", function()
			-- 	vim.diagnostic.open_float(0, { scope = "line" })
			-- end, opts)

			-- keymap.set("n", "de", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
			--
			-- keymap.set("n", "dn", function()
			-- 	vim.diagnostic.goto_next()
			-- end, opts)
			-- keymap.set("n", "dp", function()
			-- 	vim.diagnostic.goto_prev()
			-- end, opts)
			-- Jump to the definition of the word under your cursor.
			--  This is where a variable was first declared, or where a function is defined, etc.
			--  To jump back, press <C-T>.
			map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")

			-- Find references for the word under your cursor.
			map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")

			-- Jump to the implementation of the word under your cursor.
			--  Useful when your language has ways of declaring types without an actual implementation.
			map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

			-- Jump to the type of the word under your cursor.
			--  Useful when you're not sure what type a variable is and you want to see
			--  the definition of its *type*, not where it was *defined*.
			map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")

			-- Fuzzy find all the symbols in your current document.
			--  Symbols are things like variables, functions, types, etc.
			map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")

			-- Fuzzy find all the symbols in your current workspace
			--  Similar to document symbols, except searches over your whole project.
			map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

			-- Rename the variable under your cursor
			--  Most Language Servers support renaming across files, etc.
			map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

			-- Execute a code action, usually your cursor needs to be on top of an error
			-- or a suggestion from your LSP for this to activate.

			-- Opens a popup that displays documentation about the word under your cursor
			--  See `:help K` for why this keymap
			-- map("K", vim.lsp.buf.hover, "Hover Documentation")

			-- WARN: This is not Goto Definition, this is Goto Declaration.
			--  For example, in C this would take you to the header
			map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

			map("dp", vim.diagnostic.goto_prev, "Go to [D]iagnostic [P]revious message")
			map("dn", vim.diagnostic.goto_next, "Go to [D]iagnostic [N]ext message")
			map("de", vim.diagnostic.open_float, "Show [D]iagnostic [E]rror messages")
			map("dl", vim.diagnostic.setloclist, "Open [D]iagnostic quick[L]ist")
			map("dc", vim.lsp.buf.hover, "Show [D]iagnostic [C]urrent information")

			map("<M-CR>", require("actions-preview").code_actions, "Show code actions")

			map("<leader>li", function()
				local params = {
					command = "_typescript.organizeImports",
					arguments = { vim.api.nvim_buf_get_name(0) },
					title = "",
				}
				vim.lsp.buf.execute_command(params)
			end, "Organize [L]ist [I]mports")

			map("<Leader>ff", function()
				vim.lsp.buf.format({ async = true })
			end, "Format [F]ormatted code in [F]ile")

			-- map("<Leader>lr", vim.lsp.buf.rename, "Rename [R]eferences")

			-- keymap.set("n", "gr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references
			--
			-- opts.desc = "Go to declaration"
			-- -- keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration
			-- keymap.set("n", "gD", "<cmd>Telescope lsp_declaration<CR>", opts) -- go to declaration
			--
			-- opts.desc = "Show LSP definitions"
			-- keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions
			--
			-- opts.desc = "Show LSP implementations"
			-- keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations
			--
			-- opts.desc = "Show LSP type definitions"
			-- keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions
			--
			-- opts.desc = "See available code actions"
			-- keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection
			--
			-- opts.desc = "Smart rename"
			-- keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename
			--
			-- opts.desc = "Show buffer diagnostics"
			-- keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file
			--
			-- opts.desc = "Show line diagnostics"
			-- keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line
			--
			-- opts.desc = "Go to previous diagnostic"
			-- keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer
			--
			-- opts.desc = "Go to next diagnostic"
			-- keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer
			--
			-- opts.desc = "Show documentation for what is under cursor"
			-- keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor
			--
			-- opts.desc = "Restart LSP"
			-- keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
		end

		-- used to enable autocompletion (assign to every lsp server config)
		local capabilities = cmp_nvim_lsp.default_capabilities()

		-- Change the Diagnostic symbols in the sign column (gutter)
		-- (not in youtube nvim video)
		local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		-- configure html server
		lspconfig["html"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure typescript server with plugin
		lspconfig["tsserver"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure css server
		lspconfig["cssls"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		-- configure tailwindcss server
		lspconfig["tailwindcss"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
		})

		lspconfig["eslint"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			-- on_attach = function(client, bufnr)
			-- 	vim.api.nvim_create_autocmd("BufWritePre", {
			-- 		buffer = bufnr,
			-- 		command = "EslintFixAll",
			-- 	})
			-- end,
		})

		-- configure svelte server
		-- lspconfig["svelte"].setup({
		-- 	capabilities = capabilities,
		-- 	on_attach = on_attach,
		-- })

		-- configure prisma orm server
		lspconfig["prismals"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			filetypes = { "prisma" },
		})

		-- configure graphql language server
		-- lspconfig["graphql"].setup({
		-- 	capabilities = capabilities,
		-- 	on_attach = on_attach,
		-- 	filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" },
		-- })

		-- configure emmet language server
		lspconfig["emmet_ls"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less", "svelte" },
		})

		-- configure python server
		-- lspconfig["pyright"].setup({
		-- 	capabilities = capabilities,
		-- 	on_attach = on_attach,
		-- })

		-- configure lua server (with special settings)
		lspconfig["lua_ls"].setup({
			capabilities = capabilities,
			on_attach = on_attach,
			settings = { -- custom settings for lua
				Lua = {
					-- make the language server recognize "vim" global
					diagnostics = {
						globals = { "vim" },
					},
					workspace = {
						-- make language server aware of runtime files
						library = {
							[vim.fn.expand("$VIMRUNTIME/lua")] = true,
							[vim.fn.stdpath("config") .. "/lua"] = true,
						},
					},
				},
			},
		})
	end,
}
