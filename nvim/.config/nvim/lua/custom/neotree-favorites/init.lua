-- Custom source для neo-tree: Favorites
local manager = require("custom.neotree-favorites.manager")

local M = {
  name = "favorites",
  display_name = "⭐ Favorites",
}

--- Построить иерархическое дерево из плоского списка путей
---@param favorites table
---@param state table
---@return table
local function build_tree(favorites, state)
  local root_id = state.path or vim.fn.getcwd()
  local items = {}
  
  -- Создаем корневой узел
  local root = {
    id = root_id,
    name = vim.fn.fnamemodify(root_id, ":t"),
    type = "directory",
    path = root_id,
    children = {},
    loaded = true,
  }

  -- Если нет избранного, возвращаем пустое дерево
  if not favorites or vim.tbl_isempty(favorites) then
    return { root }
  end

  -- Собираем все пути и сортируем
  local paths = {}
  for path, _ in pairs(favorites) do
    table.insert(paths, path)
  end
  table.sort(paths)

  -- Строим дерево
  local tree = { [root_id] = root }
  
  for _, path in ipairs(paths) do
    local data = favorites[path]
    local parts = vim.split(path, "/", { plain = true })
    local current_path = ""
    local parent = root
    
    for i, part in ipairs(parts) do
      if part ~= "" then
        current_path = current_path .. "/" .. part
        
        if i == #parts then
          -- Это конечный узел (файл или папка)
          local node = {
            id = current_path,
            name = part,
            type = data.type,
            path = current_path,
            loaded = true,
          }
          
          -- Если это директория, добавляем children
          if data.type == "directory" then
            node.children = {}
          end
          
          table.insert(parent.children, node)
          tree[current_path] = node
        else
          -- Это промежуточная директория
          if not tree[current_path] then
            local node = {
              id = current_path,
              name = part,
              type = "directory",
              path = current_path,
              children = {},
              loaded = true,
            }
            table.insert(parent.children, node)
            tree[current_path] = node
          end
          parent = tree[current_path]
        end
      end
    end
  end

  -- Рекурсивная сортировка: директории первыми, затем файлы
  local function sort_children(node)
    if node.children then
      table.sort(node.children, function(a, b)
        if a.type == b.type then
          return a.name < b.name
        end
        return a.type == "directory"
      end)
      
      for _, child in ipairs(node.children) do
        sort_children(child)
      end
    end
  end
  
  sort_children(root)

  -- Преобразуем дерево в плоский список для neo-tree
  local function flatten(node, level, results)
    level = level or 0
    results = results or {}
    
    if level > 0 then -- Не добавляем корень
      table.insert(results, {
        id = node.id,
        name = node.name,
        type = node.type,
        path = node.path,
        extra = {},
        children = node.children or {},
        loaded = node.loaded or false,
      })
    end
    
    if node.children then
      for _, child in ipairs(node.children) do
        flatten(child, level + 1, results)
      end
    end
    
    return results
  end

  return flatten(root, 0)
end

--- Setup source
---@param opts table
---@param global_opts table
function M.setup(opts, global_opts)
  -- Инициализация не требуется
end

--- Show the favorites view
---@param state table
---@param path string|nil
---@param callback function|nil
function M.show(state, path, callback)
  return M.navigate(state, path, callback)
end

--- Navigate to a path in the favorites view
---@param state table
---@param path string
---@param callback function
function M.navigate(state, path, callback)
  state.path = path or vim.fn.getcwd()
  
  local favorites = manager.get_all_favorites()
  local items = build_tree(favorites, state)
  
  if callback then
    callback(items)
  end
  
  return items
end

--- Refresh the favorites view
---@param state table
function M.refresh(state)
  manager.clear_cache()
  local renderer = require("neo-tree.ui.renderer")
  renderer.refresh(state)
end

return M
