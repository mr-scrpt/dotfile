-- ТЕСТОВЫЙ source для проверки как neo-tree отображает структуру
-- Читает neotree-favorites-test.json и пытается показать

local M = {
  name = "test_favorites",
  display_name = "🧪 Test",
}

--- Загрузить тестовые данные
local function load_test_data()
  local test_file = vim.fn.stdpath("data") .. "/neotree-favorites-test.json"
  local file = io.open(test_file, "r")
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

--- Построить простое плоское дерево - каждая папка как отдельный элемент
local function build_simple_tree(favorites)
  local items = {}
  
  if not favorites or vim.tbl_isempty(favorites) then
    vim.notify("🧪 Test: No favorites found", vim.log.levels.WARN)
    return items
  end
  
  -- Собираем пути и сортируем
  local paths = {}
  for path, _ in pairs(favorites) do
    table.insert(paths, path)
  end
  table.sort(paths)
  
  vim.notify(string.format("🧪 Test: Found %d paths", #paths), vim.log.levels.INFO)
  
  -- Создаем простые узлы без иерархии
  for _, path in ipairs(paths) do
    local data = favorites[path]
    local name = vim.fn.fnamemodify(path, ":t")
    
    vim.notify(string.format("🧪 Creating node: %s (type=%s)", name, data.type), vim.log.levels.INFO)
    
    local node = {
      id = path,
      name = name,
      type = data.type,
      path = path,
      loaded = false,
    }
    
    if data.type == "directory" then
      node.children = {}
    end
    
    table.insert(items, node)
  end
  
  vim.notify(string.format("🧪 Test: Created %d items", #items), vim.log.levels.INFO)
  return items
end

function M.setup(opts, global_opts)
  vim.notify("🧪 Test source setup called", vim.log.levels.INFO)
end

function M.show(state, path, callback)
  return M.navigate(state, path, callback)
end

function M.navigate(state, path, callback)
  vim.notify("🧪 Test navigate called", vim.log.levels.WARN)
  
  state.path = path or vim.fn.getcwd()
  
  local favorites = load_test_data()
  local items = build_simple_tree(favorites)
  
  if callback then
    callback(items)
  end
  
  return items
end

--- Загрузка содержимого директории (для раскрытия)
function M.get_children(state, node, callback)
  vim.notify(string.format("🧪 get_children called for: %s", node.path), vim.log.levels.WARN)
  
  local path = node.path
  local scan = require("plenary.scandir")
  local children = {}
  
  local success, entries = pcall(scan.scan_dir, path, {
    hidden = false,
    depth = 1,
    add_dirs = true,
  })
  
  if not success then
    vim.notify("🧪 Failed to scan: " .. path, vim.log.levels.ERROR)
    if callback then callback({}) end
    return {}
  end
  
  vim.notify(string.format("🧪 Found %d entries in %s", #entries, path), vim.log.levels.INFO)
  
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
  vim.notify("🧪 refresh called", vim.log.levels.INFO)
  M.navigate(state, state.path)
  require("neo-tree.ui.renderer").redraw(state)
end

return M
