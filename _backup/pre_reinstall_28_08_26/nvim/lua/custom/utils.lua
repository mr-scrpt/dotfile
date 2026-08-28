--  nvim/.config/nvim/lua/custom/utils.lua

local M = {}

function M.remove_all_comments()
  local bufnr = vim.api.nvim_get_current_buf()

  -- 1. Получаем парсер (доверяем, что тип файла определен верно)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    vim.notify("Tree-sitter парсер не активен для этого файла.", vim.log.levels.WARN)
    return
  end

  -- 2. Создаем запрос для поиска узлов "comment"
  local query_str = "((comment) @comment)"
  local ok_query, query = pcall(vim.treesitter.query.parse, parser:lang(), query_str)
  if not ok_query then
    vim.notify(
      "Не удалось создать запрос для поиска комментариев.",
      vim.log.levels.ERROR
    )
    return
  end

  local root = parser:parse()[1]:root()
  local comments_list = {}

  -- 3. Собираем все комментарии
  for _, node in query:iter_captures(root, bufnr) do
    local sr, sc, er, ec = node:range() -- start_row, start_col, end_row, end_col

    -- [[ ЛОГИКА ЗАЩИТЫ SHEBANG ]]
    -- Если комментарий начинается на 0-й строке (первая строка файла)
    local is_shebang = false
    if sr == 0 then
      local line_text = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
      -- Проверяем, начинается ли она с "#!"
      if line_text:match("^#!") then
        is_shebang = true
      end
    end

    -- Добавляем в список только если это не shebang
    if not is_shebang then
      table.insert(comments_list, { sr, sc, er, ec })
    end
  end

  if #comments_list == 0 then
    vim.notify("Комментарии не найдены.", vim.log.levels.INFO)
    return
  end

  -- 4. Сортируем снизу вверх, чтобы изменения не ломали координаты
  table.sort(comments_list, function(a, b)
    if a[1] ~= b[1] then
      return a[1] > b[1]
    else
      return a[2] > b[2]
    end
  end)

  -- 5. Удаляем
  local count = 0
  for _, c in ipairs(comments_list) do
    local sr, sc, er, ec = unpack(c)
    local line = vim.api.nvim_buf_get_lines(bufnr, sr, sr + 1, false)[1] or ""
    local prefix = line:sub(1, sc)

    -- Если перед комментарием только пробелы -> заменяем строку на пустую
    if prefix:match("^%s*$") then
      local height = er - sr + 1
      local replacements = {}
      -- Создаем массив пустых строк такой же высоты
      for _ = 1, height do
        table.insert(replacements, "")
      end

      vim.api.nvim_buf_set_lines(bufnr, sr, er + 1, false, replacements)
    else
      -- Если это inline-комментарий -> вырезаем только текст комментария
      vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, {})
    end
    count = count + 1
  end

  vim.notify("Очищено комментариев: " .. count, vim.log.levels.INFO)
end
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
-- V-- ВОТ НАША НОВАЯ ФУНКЦИЯ ДЛЯ NEO-TREE --V
function M.copy_path(state)
  local node = state.tree:get_node()
  if not node then
    vim.notify("Could not get node from neo-tree", vim.log.levels.WARN)
    return
  end
  local filepath = node:get_id()
  local filename = node.name
  local modify = vim.fn.fnamemodify

  local results = {
    filepath,
    modify(filepath, ":."),
    modify(filepath, ":~"),
    filename,
    modify(filename, ":r"),
    modify(filename, ":e"),
  }

  vim.ui.select({
    "1. Absolute path: " .. results[1],
    "2. Path relative to CWD: " .. results[2],
    "3. Path relative to HOME: " .. results[3],
    "4. Filename: " .. results[4],
    "5. Filename without extension: " .. results[5],
    "6. Extension of the filename: " .. results[6],
  }, { prompt = "Choose to copy to clipboard:" }, function(choice)
    if choice then
      local i = tonumber(choice:sub(1, 1))
      if i and results[i] then
        local result = results[i]
        vim.fn.setreg("+", result)
        vim.notify("Copied to system clipboard: " .. result)
      else
        vim.notify("Invalid selection", vim.log.levels.WARN)
      end
    else
      vim.notify("Selection cancelled")
    end
  end)
end
-- ^-- КОНЕЦ НОВОЙ ФУНКЦИИ --^
-- Вспомогательная функция для grug-far
function M.open_grug_far(prefills)
  local grug_far = require("grug-far")

  if not grug_far.has_instance("explorer") then
    grug_far.open({ instanceName = "explorer" })
  else
    grug_far.open_instance("explorer")
  end
  grug_far.update_instance_prefills("explorer", prefills, false)
end

-- Команда для grug-far (обычный режим)
function M.grug_far_replace(state)
  local node = state.tree:get_node()
  local prefills = {
    paths = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
      or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h")),
  }
  M.open_grug_far(prefills)
end

-- Команда для grug-far (визуальный режим)
function M.grug_far_replace_visual(state, selected_nodes, callback)
  local paths = {}
  for _, node in pairs(selected_nodes) do
    local path = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
      or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h"))
    table.insert(paths, path)
  end
  local prefills = { paths = table.concat(paths, "\n") }
  M.open_grug_far(prefills)
end

-- Функция для маппинга 'R'
function M.grug_far_open(state)
  local node = state.tree:get_node()
  if node then
    require("grug-far").open({ prefills = { paths = node.path } })
  end
end
return M
