local Utils = require("custom.utils")
local FlatFavoritesCommands = require("custom.neotree-flat-favorites.commands")
local FlatFavoritesInfo = require("custom.neotree-flat-favorites.info")

return {
  "nvim-neo-tree/neo-tree.nvim",
  cmd = "Neotree",

  dependencies = {
    "MagicDuck/grug-far.nvim",
    "johmsalas/text-case.nvim",
  },

  keys = {
    {
      "<leader>e",
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
      "<leader>E",
      function()
        require("neo-tree.command").execute({
          source = "flat_favorites",
          toggle = true,
          position = "float",
        })
      end,
      desc = "📦 Flat Favorites",
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
    sources = { "filesystem", "buffers", "git_status", "flat_favorites" },
    popup_border_style = "rounded",

    commands = {
      grug_far_replace = Utils.grug_far_replace,
      grug_far_replace_visual = Utils.grug_far_replace_visual,
      add_to_flat_favorites = FlatFavoritesCommands.add_to_flat_favorites,
      remove_from_flat_favorites = FlatFavoritesCommands.remove_from_flat_favorites,
      toggle_flat_favorite = FlatFavoritesCommands.toggle_flat_favorite,
      show_favorites_info = FlatFavoritesInfo.show_project_info,
    },

    window = {
      mappings = {
        ["Y"] = Utils.copy_path,
        ["R"] = Utils.grug_far_open,
      },
    },

    source_selector = {
      winbar = true,
      content_layout = "center",
      sources = {
        { source = "filesystem", display_name = "  Files " },
        { source = "flat_favorites", display_name = " 📦 Favorites " },
        { source = "buffers", display_name = "  Buffers " },
        { source = "git_status", display_name = "  Git " },
      },
    },

    filesystem = {
      bind_to_cwd = false,
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      components = {
        flat_favorite_indicator = require("custom.neotree-flat-favorites.component"),
      },
      window = {
        mappings = {
          -- Toggle favorites
          ["s"] = "toggle_flat_favorite",
          -- Show project info
          ["I"] = "show_favorites_info",
        },
      },
      renderers = {
        directory = {
          { "indent" },
          { "icon" },
          { "current_filter" },
          { "name" },
          { "flat_favorite_indicator" },
        },
        file = {
          { "indent" },
          { "icon" },
          { "name", use_git_status_colors = true },
          { "flat_favorite_indicator" },
          { "git_status" },
        },
      },
    },

    flat_favorites = {
      bind_to_cwd = false,
      follow_current_file = { enabled = false },
      window = {
        mappings = {
          -- Toggle favorite
          ["s"] = "toggle_flat_favorite",
          -- Show project info
          ["I"] = "show_favorites_info",
        },
      },
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
