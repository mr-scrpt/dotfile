local Utils = require("custom.utils")
local FavoritesCommands = require("custom.neotree-favorites.commands")

return {
  "nvim-neo-tree/neo-tree.nvim",
  cmd = "Neotree",

  dependencies = {
    "MagicDuck/grug-far.nvim",
    "johmsalas/text-case.nvim",
    {
      "antosha417/nvim-lsp-file-operations",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("lsp-file-operations").setup()
      end,
    },
  },

  keys = {
    {
      "<leader>E",
      function()
        require("neo-tree.command").execute({
          source = "favorites",
          toggle = true,
          position = "float",
        })
      end,
      desc = "Favorites Explorer (Float)",
    },
    {
      "<leader>fv",
      function()
        require("neo-tree.command").execute({
          source = "flat",
          toggle = true,
          position = "float",
        })
      end,
      desc = "📦 Flat Favorites",
    },
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
    sources = { "filesystem", "buffers", "git_status", "favorites", "flat" },
    popup_border_style = "rounded",

    commands = {
      grug_far_replace = Utils.grug_far_replace,
      grug_far_replace_visual = Utils.grug_far_replace_visual,
      add_to_favorites = FavoritesCommands.add_to_favorites,
      remove_from_favorites = FavoritesCommands.remove_from_favorites,
      toggle_favorite = FavoritesCommands.toggle_favorite,
    },

    window = {
      mappings = {
        ["Y"] = Utils.copy_path,
        ["R"] = Utils.grug_far_open,
        ["S"] = "add_to_favorites",
        ["D"] = "remove_from_favorites",
      },
    },

    source_selector = {
      winbar = true,
      content_layout = "center",
      sources = {
        { source = "filesystem", display_name = "  Files " },
        { source = "buffers", display_name = "  Buffers " },
        { source = "git_status", display_name = "  Git " },
        { source = "favorites", display_name = " ⭐ Favorites " },
      },
    },

    filesystem = {
      bind_to_cwd = false,
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      components = {
        favorite_indicator = require("custom.neotree-favorites.component"),
      },
      renderers = {
        directory = {
          { "indent" },
          { "icon" },
          { "current_filter" },
          { "name" },
          { "favorite_indicator" },
        },
        file = {
          { "indent" },
          { "icon" },
          { "name", use_git_status_colors = true },
          { "favorite_indicator" },
          { "git_status" },
        },
      },
    },

    favorites = {
      bind_to_cwd = false,
      follow_current_file = { enabled = false },
      renderers = {
        directory = {
          { "indent" },
          { "icon" },
          { "current_filter" },
          { "name" },
        },
        file = {
          { "indent" },
          { "icon" },
          { "name", use_git_status_colors = true },
          { "git_status" },
        },
      },
    },

    flat = {
      bind_to_cwd = false,
      follow_current_file = { enabled = false },
      renderers = {
        directory = {
          { "indent" },
          { "icon" },
          { "current_filter" },
          { "name" },
        },
        file = {
          { "indent" },
          { "icon" },
          { "name", use_git_status_colors = true },
          { "git_status" },
        },
      },
    },
  },
}
