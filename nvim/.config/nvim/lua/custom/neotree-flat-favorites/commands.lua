-- Команды для работы с flat favorites
local manager = require("custom.neotree-flat-favorites.manager")

local M = {}

--- Добавить текущий узел в flat favorites
---@param state table
function M.add_to_flat_favorites(state)
  local node = state.tree:get_node()
  
  if not node then
    vim.notify("No node selected", vim.log.levels.WARN)
    return
  end

  local path = node:get_id()
  manager.add_path(path)
  
  -- Обновляем отображение
  local ok, renderer = pcall(require, "neo-tree.ui.renderer")
  if ok then
    pcall(renderer.redraw, state)
  end
end

--- Удалить текущий узел из flat favorites
---@param state table
function M.remove_from_flat_favorites(state)
  local node = state.tree:get_node()
  
  if not node then
    vim.notify("No node selected", vim.log.levels.WARN)
    return
  end

  local path = node:get_id()
  
  if not manager.is_favorite(path) then
    vim.notify("Path is not in flat favorites", vim.log.levels.WARN)
    return
  end

  manager.remove_path(path)
  
  -- Обновляем отображение
  local ok, renderer = pcall(require, "neo-tree.ui.renderer")
  if ok then
    pcall(renderer.redraw, state)
  end
end

--- Переключить избранное для текущего узла
---@param state table
function M.toggle_flat_favorite(state)
  local node = state.tree:get_node()
  
  if not node then
    vim.notify("No node selected", vim.log.levels.WARN)
    return
  end

  local path = node:get_id()
  
  if manager.is_favorite(path) then
    M.remove_from_flat_favorites(state)
  else
    M.add_to_flat_favorites(state)
  end
end

return M
