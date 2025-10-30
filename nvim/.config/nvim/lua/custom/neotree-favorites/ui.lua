-- UI для отображения избранного
local manager = require("custom.neotree-favorites.manager")

local M = {}

--- Показать список избранного через telescope/vim.ui.select
function M.show()
  local favorites = manager.get_all_favorites()
  
  if vim.tbl_isempty(favorites) then
    vim.notify("No favorites yet. Use <leader>S in neo-tree to add.", vim.log.levels.INFO)
    return
  end
  
  -- Собираем список путей
  local paths = {}
  for path, data in pairs(favorites) do
    table.insert(paths, {
      path = path,
      type = data.type,
      display = (data.type == "directory" and "📁 " or "📄 ") .. path
    })
  end
  
  -- Сортируем
  table.sort(paths, function(a, b)
    if a.type == b.type then
      return a.path < b.path
    end
    return a.type == "directory"
  end)
  
  -- Проверяем наличие telescope
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  
  if has_telescope then
    -- Используем telescope
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    
    pickers.new({}, {
      prompt_title = "⭐ Favorites",
      finder = finders.new_table({
        results = paths,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.path,
            path = entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            -- Открываем файл или показываем в neo-tree
            if selection.value.type == "file" then
              vim.cmd("edit " .. vim.fn.fnameescape(selection.value.path))
            else
              -- Открываем neo-tree с этой директорией
              require("neo-tree.command").execute({
                action = "focus",
                source = "filesystem",
                position = "float",
                dir = selection.value.path,
              })
            end
          end
        end)
        
        -- Добавляем маппинг для удаления из избранного
        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            manager.remove_path(selection.value.path)
            -- Обновляем список
            actions.close(prompt_bufnr)
            M.show()
          end
        end)
        
        map("n", "dd", function()
          local selection = action_state.get_selected_entry()
          if selection then
            manager.remove_path(selection.value.path)
            actions.close(prompt_bufnr)
            M.show()
          end
        end)
        
        return true
      end,
    }):find()
  else
    -- Используем vim.ui.select
    local display_items = {}
    for _, item in ipairs(paths) do
      table.insert(display_items, item.display)
    end
    
    vim.ui.select(display_items, {
      prompt = "⭐ Favorites (Enter to open, <C-d> to remove):",
    }, function(choice, idx)
      if not choice or not idx then
        return
      end
      
      local selected = paths[idx]
      if selected.type == "file" then
        vim.cmd("edit " .. vim.fn.fnameescape(selected.path))
      else
        require("neo-tree.command").execute({
          action = "focus",
          source = "filesystem",
          position = "float",
          dir = selected.path,
        })
      end
    end)
  end
end

return M
