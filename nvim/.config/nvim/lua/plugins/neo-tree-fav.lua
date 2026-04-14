--  nvim/.config/nvim/lua/plugins/neo-tree-fav.lua
return {
  {
    "neo-tree-favorites",
    -- Ключевой момент: указываем прямой путь до локальной папки разработки
    dir = "/home/mr/Hellkitchen/solution/nvim/neo-tree-fav",
    dependencies = {
      "nvim-neo-tree/neo-tree.nvim",
    },
    config = function()
      -- Инициализируем наш плагин
      require("neo-tree-favorites").setup()
    end,
  },
}
