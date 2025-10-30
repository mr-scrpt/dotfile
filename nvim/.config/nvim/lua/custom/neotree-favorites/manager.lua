-- Модуль для управления избранными файлами и папками в neo-tree
local M = {}

-- Путь к файлу с избранным
local data_path = vim.fn.stdpath("data") .. "/neotree-favorites.json"

-- Кеш для избранного (избегаем частого чтения файла)
local favorites_cache = nil

--- Загрузить избранное из файла
---@return table
function M.load_favorites()
  if favorites_cache then
    return favorites_cache
  end

  local file = io.open(data_path, "r")
  if not file then
    favorites_cache = {}
    return favorites_cache
  end

  local content = file:read("*all")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == "table" then
    favorites_cache = data
  else
    favorites_cache = {}
  end

  return favorites_cache
end

--- Сохранить избранное в файл
---@param data table
function M.save_favorites(data)
  favorites_cache = data

  -- Создаем директорию если не существует
  local dir = vim.fn.fnamemodify(data_path, ":h")
  vim.fn.mkdir(dir, "p")

  local file = io.open(data_path, "w")
  if not file then
    vim.notify("Failed to save favorites", vim.log.levels.ERROR)
    return
  end

  local json = vim.json.encode(data)
  file:write(json)
  file:close()
end

--- Нормализовать путь (абсолютный путь с / в конце для директорий)
---@param path string
---@return string
local function normalize_path(path)
  -- Преобразуем в абсолютный путь
  path = vim.fn.fnamemodify(path, ":p")
  -- Убираем trailing slash если это не корень
  if path:match("^.+/$") then
    path = path:sub(1, -2)
  end
  return path
end

--- Проверить, является ли путь директорией
---@param path string
---@return boolean
local function is_directory(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.type == "directory" or false
end

--- Получить все файлы и поддиректории рекурсивно
---@param dir string
---@return table
local function get_all_paths_recursive(dir)
  local paths = {}
  local normalized = normalize_path(dir)

  -- Добавляем саму директорию
  table.insert(paths, {
    path = normalized,
    type = "directory",
    recursive = true,
  })

  -- Рекурсивный обход
  local function scan_dir(current_dir)
    local handle = vim.loop.fs_scandir(current_dir)
    if not handle then
      return
    end

    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = current_dir .. "/" .. name
      local normalized_path = normalize_path(full_path)

      if type == "directory" then
        table.insert(paths, {
          path = normalized_path,
          type = "directory",
          recursive = true,
        })
        scan_dir(full_path)
      else
        table.insert(paths, {
          path = normalized_path,
          type = "file",
        })
      end
    end
  end

  scan_dir(normalized)
  return paths
end

--- Получить все родительские директории до корня проекта
---@param path string
---@return table
local function get_parent_dirs(path)
  local parents = {}
  local current = vim.fn.fnamemodify(path, ":h")
  local root = vim.fn.getcwd()

  while current and current ~= "/" and #current > #root do
    local normalized = normalize_path(current)
    if normalized:find(root, 1, true) == 1 then
      table.insert(parents, {
        path = normalized,
        type = "directory",
        recursive = false,
      })
    end
    current = vim.fn.fnamemodify(current, ":h")
  end

  return parents
end

--- Добавить путь в избранное
---@param path string
function M.add_path(path)
  local favorites = M.load_favorites()
  local normalized = normalize_path(path)

  if is_directory(normalized) then
    -- Если директория - добавляем всё содержимое рекурсивно
    local all_paths = get_all_paths_recursive(normalized)
    for _, item in ipairs(all_paths) do
      favorites[item.path] = {
        type = item.type,
        recursive = item.recursive or false,
      }
    end
    vim.notify("Added directory and contents to favorites: " .. normalized, vim.log.levels.INFO)
  else
    -- Если файл - добавляем файл + родительские директории (пустые)
    favorites[normalized] = {
      type = "file",
    }

    -- Добавляем родительские папки
    local parents = get_parent_dirs(normalized)
    for _, parent in ipairs(parents) do
      if not favorites[parent.path] then
        favorites[parent.path] = {
          type = "directory",
          recursive = false,
        }
      end
    end

    vim.notify("Added file to favorites: " .. normalized, vim.log.levels.INFO)
  end

  M.save_favorites(favorites)
end

--- Удалить путь из избранного
---@param path string
function M.remove_path(path)
  local favorites = M.load_favorites()
  local normalized = normalize_path(path)

  if not favorites[normalized] then
    vim.notify("Path not in favorites: " .. normalized, vim.log.levels.WARN)
    return
  end

  -- Удаляем сам путь
  favorites[normalized] = nil

  -- Если это была директория с recursive = true, удаляем всё содержимое
  for fav_path, data in pairs(favorites) do
    if fav_path:find(normalized, 1, true) == 1 and fav_path ~= normalized then
      favorites[fav_path] = nil
    end
  end

  M.save_favorites(favorites)
  vim.notify("Removed from favorites: " .. normalized, vim.log.levels.INFO)
end

--- Проверить, находится ли путь в избранном
---@param path string
---@return boolean
function M.is_favorite(path)
  local favorites = M.load_favorites()
  local normalized = normalize_path(path)
  return favorites[normalized] ~= nil
end

--- Получить все избранные пути
---@return table
function M.get_all_favorites()
  return M.load_favorites()
end

--- Очистить кеш (для принудительной перезагрузки)
function M.clear_cache()
  favorites_cache = nil
end

return M
