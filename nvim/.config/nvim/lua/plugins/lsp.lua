return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local utils = require("custom.utils")
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      opts.diagnostics.virtual_text = false
      opts.diagnostics.float = { border = "rounded" }
      -- opts.diagnostics.float.border = "rounded"

      keys[#keys + 1] = { "<leader>ck", "<cmd>lua vim.lsp.buf.hover()<CR>", desc = "Hover" }
      keys[#keys + 1] = {
        "<leader>co",
        function()
          LazyVim.lsp.execute({
            command = "typescript.organizeImports",
            arguments = { vim.api.nvim_buf_get_name(0) },
            title = "Organize Imports",
          })
        end,
        desc = "Organize Imports",
      }
      keys[#keys + 1] = {
        "<leader>cI",
        LazyVim.lsp.action["source.addMissingImports.ts"],
        desc = "Add Missing Imports",
      }
      keys[#keys + 1] = {
        "<leader>ci",
        utils.smart_import, -- <--- Вызываем нашу новую функцию
        desc = "Импорт (умный)",
      }
      keys[#keys + 1] = {
        "<leader>cD",
        LazyVim.lsp.action["source.fixAll.ts"],
        desc = "Fix all diagnostics",
      }

      keys[#keys + 1] = {
        "<leader>cu",
        LazyVim.lsp.action["source.removeUnused.ts"],
        desc = "Remove Unused (Alt)",
      }

      keys[#keys + 1] = {

        "<leader>cc",
        utils.remove_all_comments,
        desc = "Удалить все комментарии",
      }
      keys[#keys + 1] = {
        "<leader>cf",
        utils.fix_imports_by_reimporting,
        desc = "Fix Imports (Re-Import)",
      }
      keys[#keys + 1] = {
        "<leader>cec",
        function()
          vim.diagnostic.config({ virtual_lines = { only_current_line = true } })
        end,
        desc = "Toggle Virtual Lines (Current)",
      }

      -- Этот кеймап включает virtual lines для ВСЕГО документа
      keys[#keys + 1] = {
        "<leader>cea",
        function()
          vim.diagnostic.config({ virtual_lines = {} }) -- Пустая таблица включает для всех строк
        end,
        desc = "Toggle Virtual Lines (All)",
      }

      -- Я удалил ваш старый <leader>ce, так как он был для переключения.
      -- Вместо него можно добавить явное отключение:
      keys[#keys + 1] = {
        "<leader>ced", -- d for disable
        function()
          vim.diagnostic.config({ virtual_lines = false })
        end,
        desc = "Disable Virtual Lines",
      }
    end,
  },
}
