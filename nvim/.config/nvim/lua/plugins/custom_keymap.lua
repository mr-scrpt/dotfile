-- lua/plugins/custom-keymaps.lua
return {
  {
    "LazyVim/LazyVim",
    opts = {
      keys = {
        -- Ваши пользовательские кеймапы здесь
      },
    },
  },

  {
    "folke/which-key.nvim", -- Мы добавляем в существующий плагин, чтобы все работало

    opts = {},
    keys = {
      -- Навигация по списку изменений (точки редактирования)
      { "<A-h>", "g;", mode = "n", desc = "Navigate to Older Change" },
      { "<A-l>", "g,", mode = "n", desc = "Navigate to Newer Change" },

      -- Навигация по списку переходов (точки просмотра)
      -- Примечание: <A-j> это Alt+j. В некоторых терминалах может потребоваться настройка.
      { "<A-j>", "<C-O>", mode = "n", desc = "Navigate to Older Jump" },
      { "<A-k>", "<C-I>", mode = "n", desc = "Navigate to Newer Jump" },
    },
  },
}
