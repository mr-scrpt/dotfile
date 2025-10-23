return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local utils = require("custom.utils")
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      opts.diagnostics.virtual_text = false
      opts.diagnostics.float = { border = "rounded" }

      -- ... (Ваши биндинги ck, co, cI, ci, cD, cu, cc, cf, cY, cy) ...
      -- (Они должны остаться здесь, я убрал их для краткости)
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
      keys[#keys + 1] = {
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
      }
      keys[#keys + 1] = {
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
      }

      -- [[ ЛОГИКА С АВТО-ОТКЛЮЧЕНИЕМ (СТАБИЛЬНАЯ, С ОТМЕНЯЕМЫМ ТАЙМЕРОМ) ]]

      local watched_line = nil
      local autocmd_id = nil
      local timer = nil -- Храним таймер, чтобы отменить его

      -- 1. Хелпер: Очистка "сторожа" и (что ВАЖНО) отложенного таймера
      local function clear_autocmd_and_timer()
        -- Отменяем таймер, который еще не успел сработать
        if timer then
          timer:close()
          timer = nil
        end
        -- Удаляем "сторожа", который уже был установлен
        if autocmd_id then
          if vim.api.nvim_get_autocmds({ id = autocmd_id })[1] then
            vim.api.nvim_del_autocmd(autocmd_id)
          end
          autocmd_id = nil
          watched_line = nil
        end
      end

      -- 2. Хелпер: Переход и установка "сторожа"
      local function jump_and_watch(jump_func)
        -- СНАЧАЛА отменяем все, что было запущено прошлым нажатием
        clear_autocmd_and_timer()

        -- ЗАПУСКАЕМ РАБОЧУЮ НАВИГАЦИЮ
        jump_func({ float = false })

        -- ЗАПУСКАЕМ ТАЙМЕР
        -- Он создаст "сторожа" только ПОСЛЕ завершения анимации
        timer = vim.defer_fn(function()
          -- 1. Анимация завершена. Включаем режим.
          vim.diagnostic.config({ virtual_lines = { current_line = true } })

          -- 2. Запоминаем, куда мы "приземлились"
          watched_line = vim.api.nvim_win_get_cursor(0)[1]

          -- 3. Создаем "сторожа"
          autocmd_id = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buffer = 0,
            callback = function()
              local current_line = vim.api.nvim_win_get_cursor(0)[1]
              if current_line ~= watched_line then
                -- Мы ушли! Выключаем режим.
                vim.diagnostic.config({ virtual_lines = false })
                clear_autocmd_and_timer() -- Очищаем "сторожа"
              end
            end,
          })
          timer = nil -- Таймер сработал
        end, 150) -- Задержка 150мс (можете поменять на 200, если анимация дольше)
      end

      -- ce: следующая ошибка
      keys[#keys + 1] = {
        "<leader>ce",
        function()
          jump_and_watch(vim.diagnostic.goto_next)
        end,
        desc = "Next Diagnostic (Auto-Off)",
      }

      -- cE: предыдущая ошибка
      keys[#keys + 1] = {
        "<leader>cE",
        function()
          jump_and_watch(vim.diagnostic.goto_prev)
        end,
        desc = "Previous Diagnostic (Auto-Off)",
      }

      -- cs: Тогглер "Весь файл"
      keys[#keys + 1] = {
        "<leader>cs",
        function()
          -- Важно: выключаем "сторожа", т.к. мы переходим в другой режим
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
      }
    end,
  },
}
