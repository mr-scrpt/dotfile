-- Кастомный компонент для отображения индикатора избранного в neo-tree
local manager = require("custom.neotree-favorites.manager")
local highlights = require("neo-tree.ui.highlights")

return function(config, node, state)
  local text = ""
  local highlight = config.highlight or highlights.DIM_TEXT

  -- Проверяем, находится ли путь в избранном
  if node.path and manager.is_favorite(node.path) then
    text = "⭐"
    highlight = "NeoTreeGitModified" -- Используем заметный highlight
  else
    text = " " -- Пробел для выравнивания
  end

  return {
    text = text,
    highlight = highlight,
  }
end
