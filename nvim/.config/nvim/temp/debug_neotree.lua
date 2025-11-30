-- Отладка для neo-tree mappings

vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function()
    vim.defer_fn(function()
      local bufnr = vim.api.nvim_get_current_buf()
      local state = require("neo-tree.sources.manager").get_state("flat_favorites")
      
      if state and state.name == "flat_favorites" then
        vim.notify("[DEBUG autocmd] flat_favorites buffer detected", vim.log.levels.WARN)
        vim.notify("[DEBUG autocmd] state.commands exists: " .. tostring(state.commands ~= nil), vim.log.levels.WARN)
        
        if state.commands then
          vim.notify("[DEBUG autocmd] fuzzy_finder in commands: " .. tostring(state.commands.fuzzy_finder ~= nil), vim.log.levels.WARN)
          vim.notify("[DEBUG autocmd] Commands count: " .. vim.tbl_count(state.commands), vim.log.levels.WARN)
        end
        
        if state.window and state.window.mappings then
          vim.notify("[DEBUG autocmd] Mappings count: " .. vim.tbl_count(state.window.mappings), vim.log.levels.WARN)
          vim.notify("[DEBUG autocmd] / mapping: " .. vim.inspect(state.window.mappings["/"]), vim.log.levels.WARN)
        end
        
        -- Проверяем keymap
        local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
        for _, km in ipairs(keymaps) do
          if km.lhs == '/' then
            vim.notify("[DEBUG autocmd] / keymap found: " .. vim.inspect(km), vim.log.levels.WARN)
          end
        end
      end
    end, 100)
  end,
})
