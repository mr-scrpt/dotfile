-- Команды для работы с избранным в neo-tree
local manager = require("custom.neotree-favorites.manager")

local M = {}

--- Добавить текущий узел в избранное
---@param state table
function M.add_to_favorites(state)
  local node = state.tree:get_node()
  
  if not node then
    vim.notify("No node selected", vim.log.levels.WARN)
    return
  end

  local path = node:get_id()
  manager.add_path(path)
  
  -- Обновляем отображение через redraw
  local ok, renderer = pcall(require, "neo-tree.ui.renderer")
  if ok then
    pcall(renderer.redraw, state)
  end
end

--- Удалить текущий узел из избранного
---@param state table
function M.remove_from_favorites(state)
  local node = state.tree:get_node()
  
  if not node then
    vim.notify("No node selected", vim.log.levels.WARN)
    return
  end

  local path = node:get_id()
  
  if not manager.is_favorite(path) then
    vim.notify("Path is not in favorites", vim.log.levels.WARN)
    return
  end
  
  manager.remove_path(path)
  
  -- Обновляем отображение через redraw
  local ok, renderer = pcall(require, "neo-tree.ui.renderer")
  if ok then
    pcall(renderer.redraw, state)
  end
end

--- Переключить статус избранного для текущего узла
---@param state table
function M.toggle_favorite(state)
  local node = state.tree:get_node()
  
  if not node then
    vim.notify("No node selected", vim.log.levels.WARN)
    return
  end

  local path = node:get_id()
  
  if manager.is_favorite(path) then
    M.remove_from_favorites(state)
  else
    M.add_to_favorites(state)
  end
end

return M
