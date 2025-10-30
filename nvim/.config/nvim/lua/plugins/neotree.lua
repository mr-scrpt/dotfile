local Utils = require("custom.utils")

return {
  "nvim-neo-tree/neo-tree.nvim",
  cmd = "Neotree",

  -- V-- ДОБАВЛЯЕМ ЗАВИСИМОСТИ --V
  dependencies = {
    "MagicDuck/grug-far.nvim",
    "johmsalas/text-case.nvim", -- (Опциональная зависимость grug-far из твоего старого конфига)
  },
  -- ^-- ДОБАВЛЯЕМ ЗАВИСИМОСТИ --^

  keys = {
    {
      "<leader>fe",
      function()
        require("neo-tree.command").execute({
          toggle = true,
          position = "float",
          reveal = true,
          dir = LazyVim.root(),
        })
      end,
      desc = "Explorer NeoTree (Root Dir, Float)",
    },
    {
      "<leader>fE",
      function()
        require("neo-tree.command").execute({
          toggle = true,
          position = "right",
          reveal = true,
          dir = vim.uv.cwd(),
        })
      end,
      desc = "Explorer NeoTree (cwd, Right)",
    },
    { "<leader>e", "<leader>fe", desc = "Explorer NeoTree (Root Dir, Float)", remap = true },
    { "<leader>E", "<leader>fE", desc = "Explorer NeoTree (cwd, Right)", remap = true },
    {
      "<leader>ge",
      function()
        require("neo-tree.command").execute({ source = "git_status", toggle = true, position = "float" })
      end,
      desc = "Git Explorer (Float)",
    },
    {
      "<leader>be",
      function()
        require("neo-tree.command").execute({ source = "buffers", toggle = true, position = "float" })
      end,
      desc = "Buffer Explorer (Float)",
    },
  },

  opts = {
    popup_border_style = "rounded",

    -- V-- ДОБАВЛЯЕМ КОМАНДЫ --V
    commands = {
      grug_far_replace = Utils.grug_far_replace,
      grug_far_replace_visual = Utils.grug_far_replace_visual,
    },
    -- ^-- ДОБАВЛЯЕМ КОМАНДЫ --^

    window = {
      mappings = {
        ["Y"] = Utils.copy_path, -- Наша функция с выбором
        ["R"] = Utils.grug_far_open, -- Новый маппинг для grug-far
      },
    },
  },
}
