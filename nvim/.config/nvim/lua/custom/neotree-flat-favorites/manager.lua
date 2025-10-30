-- Менеджер для flat favorites
-- Хранит ТОЛЬКО явно добавленные элементы (корни), без вложенных файлов

local M = {}

-- Путь к файлу с flat favorites
local data_path = vim.fn.stdpath("data") .. "/neotree-flat-favorites.json"

-- Кеш
local favorites_cache = nil

--- Загрузить flat favorites из файла
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
    return data
  end

  favorites_cache = {}
  return favorites_cache
end

--- Сохранить flat favorites в файл
---@param favorites table
function M.save_favorites(favorites)
  favorites_cache = favorites

  local ok, json = pcall(vim.json.encode, favorites)
  if not ok then
    vim.notify("Failed to encode flat favorites", vim.log.levels.ERROR)
    return
  end

  local file = io.open(data_path, "w")
  if not file then
    vim.notify("Failed to save flat favorites", vim.log.levels.ERROR)
    return
  end

  file:write(json)
  file:close()
end

--- Нормализовать путь
---@param path string
---@return string
local function normalize_path(path)
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

--- Добавить путь в flat favorites
--- Добавляется ТОЛЬКО сам элемент, без рекурсивного обхода
---@param path string
function M.add_path(path)
  local favorites = M.load_favorites()
  local normalized = normalize_path(path)

  -- Добавляем только сам выбранный элемент
  if is_directory(normalized) then
    favorites[normalized] = {
      type = "directory",
      added_at = os.time(),
    }
    vim.notify("Added to flat favorites: " .. normalized, vim.log.levels.INFO)
  else
    favorites[normalized] = {
      type = "file",
      added_at = os.time(),
    }
    vim.notify("Added to flat favorites: " .. normalized, vim.log.levels.INFO)
  end

  M.save_favorites(favorites)
end

--- Удалить путь из flat favorites
---@param path string
function M.remove_path(path)
  local favorites = M.load_favorites()
  local normalized = normalize_path(path)

  if not favorites[normalized] then
    vim.notify("Path not in flat favorites: " .. normalized, vim.log.levels.WARN)
    return
  end

  favorites[normalized] = nil
  M.save_favorites(favorites)
  vim.notify("Removed from flat favorites: " .. normalized, vim.log.levels.INFO)
end

--- Проверить, находится ли путь в flat favorites
---@param path string
---@return boolean
function M.is_favorite(path)
  local favorites = M.load_favorites()
  local normalized = normalize_path(path)
  return favorites[normalized] ~= nil
end

--- Получить все flat favorites
---@return table
function M.get_all_favorites()
  return M.load_favorites()
end

--- Очистить кеш
function M.clear_cache()
  favorites_cache = nil
end

return M
