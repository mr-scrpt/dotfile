-- В файле: lua/custom/utils.lua

local M = {}

---
--- Удаляет все комментарии из текущего буфера, используя Tree-sitter.
--- Работает для любого языка с установленным парсером.
---
function M.remove_all_comments()
  local bufnr = vim.api.nvim_get_current_buf()

  -- 1. Получаем парсер для текущего буфера. Это самый надежный способ.
  local parser = vim.treesitter.get_parser(bufnr)

  -- 2. Проверяем, существует ли активный парсер для этого файла.
  --    Эта проверка обрабатывает случаи, когда язык не установлен или не поддерживается.
  if not parser or not parser:lang() then
    vim.notify(
      "Tree-sitter парсер для этого языка не активен.",
      vim.log.levels.WARN,
      { title = "Ошибка" }
    )
    return
  end

  -- 3. Получаем язык из активного парсера.
  local lang = parser:lang()

  local query_str = "(comment) @comment"
  local query = vim.treesitter.query.parse(lang, query_str)

  if not query then
    vim.notify(
      "Не удалось создать Tree-sitter запрос для комментариев.",
      vim.log.levels.ERROR
    )
    return
  end

  local ranges_to_delete = {}
  local root = parser:parse()[1]:root()

  for _, node in query:iter_captures(root, bufnr) do
    local start_row, start_col, end_row, end_col = node:range()
    local line_content = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""

    if line_content:match("^%s*$") ~= line_content:sub(start_col + 1, end_col) then
      table.insert(ranges_to_delete, { start_row, start_col, end_row, end_col, "" })
    else
      table.insert(ranges_to_delete, { start_row, 0, start_row + 1, 0, "" })
    end
  end

  if #ranges_to_delete == 0 then
    vim.notify("Комментарии не найдены.", vim.log.levels.INFO)
    return
  end

  table.sort(ranges_to_delete, function(a, b)
    return a[1] > b[1] or (a[1] == b[1] and a[2] > b[2])
  end)

  -- Применяем изменения в одной "транзакции" для лучшей производительности
  vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, {})
  for _, range in ipairs(ranges_to_delete) do
    vim.api.nvim_buf_set_text(bufnr, range[1], range[2], range[3], range[4], { range[5] })
  end

  vim.notify("Все комментарии удалены с помощью Tree-sitter!", vim.log.levels.INFO)
end

-- В файле: lua/custom/utils.lua
-- ВРЕМЕННАЯ ДЕБАГ-ВЕРСИЯ ФУНКЦИИ

-- function M.fix_imports_by_reimporting()
--   local bufnr = vim.api.nvim_get_current_buf()
--
--   print("--- Отладка диагностик ---")
--   local diagnostics = vim.diagnostic.get(bufnr, { severity = vim.lsp.protocol.DiagnosticSeverity.Error })
--
--   if #diagnostics == 0 then
--     print("Не найдено диагностик с уровнем 'Error'.")
--     return
--   end
--
--   -- Распечатываем информацию о каждой ошибке
--   for i, diag in ipairs(diagnostics) do
--     print("Диагностика #" .. i .. ":")
--     print(vim.inspect(diag))
--   end
--
--   print("--- Конец отладки ---")
--   vim.notify(
--     "Данные отладки выведены. Проверьте сообщения (:messages).",
--     vim.log.levels.INFO
--   )
-- end
-- В файле: lua/custom/utils.lua

-- ... (остальная часть вашего файла) ...

---
--- Исправляет сломанные импорты путем их удаления и повторного импортирования.
---
-- В файле: lua/custom/utils.lua

-- ... (остальная часть вашего файла) ...

---
--- Исправляет сломанные импорты путем их удаления и повторного импортирования.
---
-- В файле: lua/custom/utils.lua

-- ... (остальная часть вашего файла) ...

---
--- Исправляет сломанные импорты путем их удаления и последующего импортирования.
--- Делает это последовательно, дожидаясь обновления диагностик от LSP-сервера.
---
function M.fix_imports_by_reimporting()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines_to_delete = {}

  local diagnostics = vim.diagnostic.get(bufnr, { severity = vim.lsp.protocol.DiagnosticSeverity.Error })

  for _, diag in ipairs(diagnostics) do
    if diag.code == 2307 then
      lines_to_delete[diag.lnum + 1] = true
    end
  end

  if not next(lines_to_delete) then
    vim.notify("Не найдено сломанных импортов (ошибка 2307).", vim.log.levels.INFO)
    return
  end

  -- 1. Создаем временную группу для нашей автокоманды, чтобы она не мешала другим.
  local group = vim.api.nvim_create_augroup("LspFixImportsOnce", { clear = true })

  -- 2. Создаем автокоманду, которая сработает ОДИН РАЗ после изменения диагностик в текущем файле.
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    buffer = bufnr, -- Привязываемся только к текущему буферу
    once = true, -- Автокоманда автоматически удалится после первого же срабатывания
    callback = function()
      vim.schedule(function()
        -- 3. Теперь, когда диагностики обновлены, безопасно вызываем действие.
        if LazyVim and LazyVim.lsp and LazyVim.lsp.action and LazyVim.lsp.action["source.addMissingImports.ts"] then
          LazyVim.lsp.action["source.addMissingImports.ts"](bufnr)
          vim.notify("Импорты перестроены.", vim.log.levels.INFO)
        else
          vim.notify("Не удалось найти действие 'addMissingImports'.", vim.log.levels.ERROR)
        end
      end)
    end,
  })

  -- 4. И только теперь удаляем строки. Это вызовет обновление диагностик и запустит нашу автокоманду.
  local sorted_lines = {}
  for line_num, _ in pairs(lines_to_delete) do
    table.insert(sorted_lines, line_num)
  end
  table.sort(sorted_lines, function(a, b)
    return a > b
  end)

  for _, line_num in ipairs(sorted_lines) do
    vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { "" })
  end
end
--

function M.smart_import()
  local bufnr = vim.api.nvim_get_current_buf()

  local client = (vim.lsp.get_clients({ bufnr = bufnr }) or {})[1]

  if not client then
    vim.notify("LSP-клиент не активен для этого буфера.", vim.log.levels.WARN)

    return
  end

  -- 1. Собираем задачи, правильно извлекая координаты ошибки.

  local tasks = {}

  local task_names = {}

  for _, diag in ipairs(vim.diagnostic.get(bufnr)) do
    if diag.code == 2304 then
      local name = diag.message:match("Cannot find name '([^']*)'")

      -- Используем `user_data.lsp.range`, так как это стандартный путь.

      if name and not task_names[name] and diag.user_data and diag.user_data.lsp and diag.user_data.lsp.range then
        table.insert(tasks, {

          name = name,

          pos = { diag.user_data.lsp.range.start.line + 1, diag.user_data.lsp.range.start.character },
        })

        task_names[name] = true
      end
    end
  end

  if #tasks == 0 then
    vim.notify(
      "Не найдено необъявленных компонентов (ошибка 2304).",
      vim.log.levels.INFO
    )

    return
  end

  -- 2. Создаем функцию для последовательной обработки каждой задачи.

  local function process_next_task()
    if #tasks == 0 then
      vim.notify("Все импорты обработаны.", vim.log.levels.INFO)

      return
    end

    local task = table.remove(tasks, 1)

    -- Перемещаем курсор на место ошибки

    vim.api.nvim_win_set_cursor(0, task.pos)

    -- Вызываем code_action с `nil` (самый безопасный способ)

    vim.lsp.buf.code_action(nil, function(err, actions)
      if err or not actions or #actions == 0 then
        process_next_task()

        return
      end

      -- 3. Фильтруем действия, ища варианты импорта.

      local import_actions = {}

      for _, action in ipairs(actions) do
        -- Этот фильтр ищет наиболее вероятные названия для действий импорта

        if action.kind == "quickfix" and (action.title:find("Import") or action.title:find("import")) then
          table.insert(import_actions, action)
        end
      end

      if #import_actions == 0 then
        -- Если ничего не найдено, просто переходим к следующей задаче

        vim.defer_fn(process_next_task, 50)

        return
      end

      -- Весь остальной код для выбора и применения

      local choices = {}

      for _, action in ipairs(import_actions) do
        local choice = action.title:match("from (.+)") or action.title

        table.insert(choices, choice)
      end

      table.sort(choices, function(a, b)
        local a_is_local = a:find("^'%.")

        local b_is_local = b:find("^'%.")

        if a_is_local and not b_is_local then
          return true
        end

        if not a_is_local and b_is_local then
          return false
        end

        return a < b
      end)

      local prompt = "Импорт для '" .. task.name .. "':"

      vim.ui.select(choices, { prompt = prompt }, function(choice)
        if choice then
          for i, action_choice in ipairs(choices) do
            local current_action_title = (import_actions[i].title:match("from (.+)") or import_actions[i].title)

            if current_action_title == choice then
              vim.lsp.util.apply_workspace_edit(
                import_actions[i].edit,
                { position_encoding = client.position_encoding }
              )

              break
            end
          end
        end

        vim.defer_fn(process_next_task, 200)
      end)
    end)
  end

  process_next_task()
end
return M
