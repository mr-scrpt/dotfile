-- Flat Favorites source для neo-tree
-- Каждый добавленный элемент отображается как отдельный корень на верхнем уровне

local renderer = require("neo-tree.ui.renderer")
local file_items = require("neo-tree.sources.common.file-items")
local utils = require("neo-tree.utils")

local M = {
  name = "flat_favorites",
  display_name = "📦 Flat Favorites",
}

local manager = require("custom.neotree-flat-favorites.manager")

--- Загрузить всё содержимое папки рекурсивно
---@param parent_item table
---@param parent_path string
local function load_all_recursive(parent_item, parent_path)
  local scan = require("plenary.scandir")
  
  local success, entries = pcall(scan.scan_dir, parent_path, {
    hidden = false,
    depth = 1,
    add_dirs = true,
  })
  
  if not success then
    parent_item.loaded = true
    return
  end
  
  parent_item.children = {}
  
  for _, entry in ipairs(entries) do
    local stat = vim.loop.fs_stat(entry)
    if stat then
      local name = vim.fn.fnamemodify(entry, ":t")
      local is_dir = stat.type == "directory"
      
      local child = {
        id = entry,
        name = name,
        parent_path = parent_path,
        path = entry,
        type = is_dir and "directory" or "file",
        loaded = false,
      }
      
      if is_dir then
        child.children = {}
        -- Рекурсивно загружаем содержимое
        load_all_recursive(child, entry)
      else
        child.ext = name:match("%.([^%.]+)$")
      end
      
      table.insert(parent_item.children, child)
    end
  end
  
  -- Сортируем
  table.sort(parent_item.children, function(a, b)
    if a.type == b.type then
      return a.name < b.name
    end
    return a.type == "directory"
  end)
  
  parent_item.loaded = true
end

--- Setup source
---@param config table
---@param global_config table
function M.setup(config, global_config)
  -- Настройка не требуется
end


--- Navigate - главный метод для отображения дерева
---@param state table
---@param path string|nil
---@param path_to_reveal string|nil
---@param callback function|nil
---@param async boolean|nil
function M.navigate(state, path, path_to_reveal, callback, async)
  if state.loading then
    return
  end
  
  state.loading = true
  state.dirty = false
  state.path = path or vim.fn.getcwd()
  
  -- Создаем контекст для file_items
  local context = file_items.create_context()
  context.state = state
  
  -- Создаем корневую папку
  local root = file_items.create_item(context, state.path, "directory")
  root.name = "📦 Flat Favorites"
  root.loaded = true
  root.search_pattern = state.search_pattern
  context.folders[root.path] = root
  
  -- Получаем flat favorites
  local favorites = manager.get_all_favorites()
  
  if not vim.tbl_isempty(favorites) then
    -- Собираем пути и сортируем
    local paths = {}
    for fav_path, data in pairs(favorites) do
      table.insert(paths, { path = fav_path, type = data.type })
    end
    
    table.sort(paths, function(a, b)
      if a.type == b.type then
        return a.path < b.path
      end
      return a.type == "directory"
    end)
    
    -- Создаем элементы вручную БЕЗ file_items чтобы избежать автоматической иерархии
    for _, item_data in ipairs(paths) do
      local fav_path = item_data.path
      local name = vim.fn.fnamemodify(fav_path, ":t")
      
      -- Создаем элемент вручную
      local item = {
        id = fav_path,
        name = name,
        parent_path = root.path,  -- Родитель - root, НЕ реальный parent в ФС!
        path = fav_path,
        type = item_data.type,
        loaded = false,
        extra = { is_flat_favorite = true },
      }
      
      if item_data.type == "directory" then
        item.children = {}
        context.folders[fav_path] = item
        -- Загружаем ВСЁ содержимое рекурсивно сразу
        load_all_recursive(item, fav_path)
      end
      
      -- Добавляем напрямую в root
      table.insert(root.children, item)
    end
  end
  
  -- Устанавливаем expanded nodes
  state.default_expanded_nodes = {}
  for id, _ in pairs(context.folders) do
    table.insert(state.default_expanded_nodes, id)
  end
  
  -- Сортируем детей корня
  if root.children then
    file_items.advanced_sort(root.children, state)
  end
  
  -- Отображаем дерево
  renderer.show_nodes({ root }, state)
  
  state.loading = false
  
  if type(callback) == "function" then
    vim.schedule(callback)
  end
end

return M
