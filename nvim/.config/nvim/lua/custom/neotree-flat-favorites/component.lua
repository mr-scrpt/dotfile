-- Кастомный компонент для отображения индикатора flat favorites в neo-tree
local manager = require("custom.neotree-flat-favorites.manager")
local highlights = require("neo-tree.ui.highlights")

-- Кеш favorites для текущей сессии рендеринга
local favorites_cache = nil
local cache_time = 0

return function(config, node, state)
  local text = ""
  local highlight = config.highlight or highlights.DIM_TEXT

  -- Кешируем favorites на 100ms чтобы не загружать для каждого узла
  local now = vim.loop.now()
  if not favorites_cache or (now - cache_time) > 100 then
    favorites_cache = manager.get_all_favorites()
    cache_time = now
  end

  -- Проверяем, находится ли путь в flat favorites
  if node.path and favorites_cache[node.path] then
    local fav_info = favorites_cache[node.path]
    
    -- Показываем invalid только в flat_favorites view, не в filesystem
    if state.name == "flat_favorites" and fav_info.invalid then
      text = "⚠️ "
      highlight = "NeoTreeGitDeleted"
    else
      text = "📦"
      highlight = "NeoTreeGitModified"
    end
  else
    text = "  " -- Два пробела для выравнивания
  end

  return {
    text = text,
    highlight = highlight,
  }
end
