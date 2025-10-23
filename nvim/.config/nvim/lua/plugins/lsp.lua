return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local utils = require("custom.utils")
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      opts.diagnostics.virtual_text = false
      opts.diagnostics.float = { border = "rounded" }

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
        utils.smart_import,
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

      -- Копирование всех ошибок из файла
      keys[#keys + 1] = {
        "<leader>cY",
        function()
          local diagnostics = vim.diagnostic.get(0) -- 0 = текущий буфер
          if #diagnostics == 0 then
            vim.notify("Нет ошибок в файле", vim.log.levels.INFO)
            return
          end

          local lines = {}
          for _, diag in ipairs(diagnostics) do
            local severity = vim.diagnostic.severity[diag.severity]
            local line_text = string.format("[%s] Line %d: %s", severity, diag.lnum + 1, diag.message)
            table.insert(lines, line_text)
          end

          local result = table.concat(lines, "\n")
          vim.fn.setreg("+", result)
          vim.notify(string.format("Скопировано %d ошибок", #diagnostics), vim.log.levels.INFO)
        end,
        desc = "Copy All Diagnostics",
      }

      -- Копирование ошибки из текущей строки
      keys[#keys + 1] = {
        "<leader>cy",
        function()
          local line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed
          local diagnostics = vim.diagnostic.get(0, { lnum = line })

          if #diagnostics == 0 then
            vim.notify("Нет ошибок на текущей строке", vim.log.levels.INFO)
            return
          end

          local lines = {}
          for _, diag in ipairs(diagnostics) do
            local severity = vim.diagnostic.severity[diag.severity]
            local line_text = string.format("[%s] Line %d: %s", severity, diag.lnum + 1, diag.message)
            table.insert(lines, line_text)
          end

          local result = table.concat(lines, "\n")
          vim.fn.setreg("+", result)
          vim.notify(
            string.format("Скопировано %d ошибок с строки %d", #diagnostics, line + 1),
            vim.log.levels.INFO
          )
        end,
        desc = "Copy Line Diagnostics",
      }

      keys[#keys + 1] = {
        "<leader>cE",
        function()
          vim.diagnostic.config({ virtual_lines = { only_current_line = true } })
        end,
        desc = "Toggle Virtual Lines (Current)",
      }
      keys[#keys + 1] = {
        "<leader>ce",
        function()
          vim.diagnostic.config({ virtual_lines = {} })
        end,
        desc = "Toggle Virtual Lines (All)",
      }
      keys[#keys + 1] = {
        "<leader>cs",
        function()
          vim.diagnostic.config({ virtual_lines = false })
        end,
        desc = "Disable Virtual Lines",
      }
    end,
  },
}
