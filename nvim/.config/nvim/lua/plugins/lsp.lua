return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local utils = require("custom.utils")

      -- НЕ ИСПОЛЬЗУЕМ больше эту строку! Она устарела:
      -- local keys = require("lazyvim.plugins.lsp.keymaps").get()  ← УДАЛИЛИ!

      -- Настраиваем diagnostics
      opts.diagnostics = opts.diagnostics or {}
      opts.diagnostics.virtual_text = false
      opts.diagnostics.float = { border = "rounded" }

      -- КРИТИЧЕСКИ ВАЖНО: Добавляем capabilities с поддержкой file operations
      opts.capabilities = opts.capabilities or {}
      opts.capabilities.workspace = opts.capabilities.workspace or {}
      opts.capabilities.workspace.fileOperations = {
        dynamicRegistration = true,
        didCreate = true,
        willCreate = true,
        didRename = true,
        willRename = true,
        didDelete = true,
        willDelete = true,
      }

      -- Настраиваем серверы (НОВЫЙ способ для LazyVim)
      opts.servers = opts.servers or {}

      -- Глобальные keymaps для всех LSP серверов
      opts.servers["*"] = opts.servers["*"] or {}
      opts.servers["*"].keys = opts.servers["*"].keys or {}

      -- НОВЫЙ способ: берем keys из servers["*"]
      local keys = opts.servers["*"].keys

      -- Добавляем ваши кастомные биндинги
      vim.list_extend(keys, {
        { "<leader>ck", vim.lsp.buf.hover, desc = "Hover" },
        {
          "<leader>co",
          function()
            LazyVim.lsp.execute({
              command = "typescript.organizeImports",
              arguments = { vim.api.nvim_buf_get_name(0) },
              title = "Organize Imports",
            })
          end,
          desc = "Organize Imports",
        },
        {
          "<leader>cI",
          LazyVim.lsp.action["source.addMissingImports.ts"],
          desc = "Add Missing Imports",
        },
        {
          "<leader>ci",
          utils.smart_import,
          desc = "Импорт (умный)",
        },
        {
          "<leader>cD",
          LazyVim.lsp.action["source.fixAll.ts"],
          desc = "Fix all diagnostics",
        },
        {
          "<leader>cu",
          LazyVim.lsp.action["source.removeUnused.ts"],
          desc = "Remove Unused (Alt)",
        },
        {
          "<leader>cc",
          utils.remove_all_comments,
          desc = "Удалить все комментарии",
        },
        {
          "<leader>cf",
          utils.fix_imports_by_reimporting,
          desc = "Fix Imports (Re-Import)",
        },
        {
          "<leader>cY",
          function()
            local diagnostics = vim.diagnostic.get(0)
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
        },
        {
          "<leader>cy",
          function()
            local line = vim.api.nvim_win_get_cursor(0)[1] - 1
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
        },
      })

      -- [[ ЛОГИКА С АВТО-ОТКЛЮЧЕНИЕМ (СТАБИЛЬНАЯ, С ОТМЕНЯЕМЫМ ТАЙМЕРОМ) ]]

      local watched_line = nil
      local autocmd_id = nil
      local timer = nil

      -- Хелпер: Очистка "сторожа" и таймера
      local function clear_autocmd_and_timer()
        if timer then
          timer:close()
          timer = nil
        end
        if autocmd_id then
          if vim.api.nvim_get_autocmds({ id = autocmd_id })[1] then
            vim.api.nvim_del_autocmd(autocmd_id)
          end
          autocmd_id = nil
          watched_line = nil
        end
      end

      -- Хелпер: Переход и установка "сторожа"
      local function jump_and_watch(jump_func)
        clear_autocmd_and_timer()
        jump_func({ float = false })

        timer = vim.defer_fn(function()
          vim.diagnostic.config({ virtual_lines = { current_line = true } })
          watched_line = vim.api.nvim_win_get_cursor(0)[1]

          autocmd_id = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buffer = 0,
            callback = function()
              local current_line = vim.api.nvim_win_get_cursor(0)[1]
              if current_line ~= watched_line then
                vim.diagnostic.config({ virtual_lines = false })
                clear_autocmd_and_timer()
              end
            end,
          })
          timer = nil
        end, 150)
      end

      -- Добавляем биндинги для навигации по ошибкам
      vim.list_extend(keys, {
        {
          "<leader>ce",
          function()
            jump_and_watch(vim.diagnostic.goto_next)
          end,
          desc = "Next Diagnostic (Auto-Off)",
        },
        {
          "<leader>cE",
          function()
            jump_and_watch(vim.diagnostic.goto_prev)
          end,
          desc = "Previous Diagnostic (Auto-Off)",
        },
        {
          "<leader>cs",
          function()
            clear_autocmd_and_timer()

            local config = vim.diagnostic.config()
            if
              (config.virtual_lines == true)
              or (type(config.virtual_lines) == "table" and not config.virtual_lines.current_line)
            then
              vim.diagnostic.config({ virtual_lines = false })
              vim.notify("Виртуальные линии (All): ВЫКЛ", vim.log.levels.INFO)
            else
              vim.diagnostic.config({ virtual_lines = true })
              vim.notify("Виртуальные линии (All): ВКЛ", vim.log.levels.INFO)
            end
          end,
          desc = "Toggle Virtual Lines (All)",
        },
      })

      return opts
    end,
  },
}
