-- Flat source для neo-tree: показывает избранное без полной иерархии
-- Каждая избранная папка отображается как отдельный корень

local M = {
  name = "flat",
  display_name = "📦 Flat",
}

--- Загрузить избранное
local function load_favorites()
  local favorites_file = vim.fn.stdpath("data") .. "/neotree-favorites.json"
  local file = io.open(favorites_file, "r")
  if not file then
    return {}
  end
  
  local content = file:read("*all")
  file:close()
  
  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == "table" then
    return data
  end
  
  return {}
end

--- Построить плоское дерево - каждая папка как отдельный корень
local function build_flat_tree(favorites)
  local items = {}
  
  if not favorites or vim.tbl_isempty(favorites) then
    return items
  end
  
  -- Собираем пути и сортируем
  local paths = {}
  for path, _ in pairs(favorites) do
    table.insert(paths, path)
  end
  table.sort(paths)
  
  -- Создаем узлы без иерархии - каждый путь как отдельный корень
  for _, path in ipairs(paths) do
    local data = favorites[path]
    -- Показываем относительный путь от HOME
    local home = vim.fn.expand("~")
    local display_name
    if path:sub(1, #home) == home then
      display_name = "~" .. path:sub(#home + 1)
    else
      display_name = path
    end
    
    local node = {
      id = path,
      name = display_name,
      type = data.type,
      path = path,
      loaded = false,
    }
    
    if data.type == "directory" then
      node.children = {}
    end
    
    table.insert(items, node)
  end
  
  return items
end

function M.setup(opts, global_opts)
  -- Инициализация не требуется
end

function M.show(state, path, callback)
  return M.navigate(state, path, callback)
end

function M.navigate(state, path, callback)
  state.path = path or vim.fn.getcwd()
  
  local favorites = load_favorites()
  local items = build_flat_tree(favorites)
  
  if callback then
    callback(items)
  end
  
  return items
end

--- Загрузка содержимого директории (для раскрытия)
function M.get_children(state, node, callback)
  local path = node.path
  local scan = require("plenary.scandir")
  local children = {}
  
  local success, entries = pcall(scan.scan_dir, path, {
    hidden = false,
    depth = 1,
    add_dirs = true,
  })
  
  if not success then
    if callback then callback({}) end
    return {}
  end
  
  for _, entry in ipairs(entries) do
    local name = vim.fn.fnamemodify(entry, ":t")
    local is_dir = vim.fn.isdirectory(entry) == 1
    
    table.insert(children, {
      id = entry,
      name = name,
      type = is_dir and "directory" or "file",
      path = entry,
      loaded = false,
      children = is_dir and {} or nil,
    })
  end
  
  -- Сортируем
  table.sort(children, function(a, b)
    if a.type == b.type then
      return a.name < b.name
    end
    return a.type == "directory"
  end)
  
  if callback then
    callback(children)
  end
  
  return children
end

function M.refresh(state)
  M.navigate(state, state.path)
  require("neo-tree.ui.renderer").redraw(state)
end

return M
