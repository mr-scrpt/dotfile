local Utils = require("custom.utils")

return {
  "nvim-neo-tree/neo-tree.nvim",
  cmd = "Neotree",

  dependencies = {
    "MagicDuck/grug-far.nvim",
    "johmsalas/text-case.nvim",
    "mr-scrpt/neotree-favorites.nvim",
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
          source = "neotree-favorites",
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
    sources = { "filesystem", "buffers", "git_status", "neotree-favorites" },
    popup_border_style = "rounded",

    commands = {
      grug_far_replace = Utils.grug_far_replace,
      grug_far_replace_visual = Utils.grug_far_replace_visual,
      add_to_flat_favorites = function(state)
        require("neotree-favorites.commands").add_to_flat_favorites(state)
      end,
      remove_from_flat_favorites = function(state)
        require("neotree-favorites.commands").remove_from_flat_favorites(state)
      end,
      toggle_flat_favorite = function(state)
        require("neotree-favorites.commands").toggle_flat_favorite(state)
      end,
      show_favorites_info = function(state)
        require("neotree-favorites.info").show_project_info()
      end,
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
        { source = "neotree-favorites", display_name = " 📦 Favorites " },
        { source = "buffers", display_name = "  Buffers " },
        { source = "git_status", display_name = "  Git " },
      },
    },

    filesystem = {
      bind_to_cwd = false,
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      components = {
        flat_favorite_indicator = function(config, node, state)
          return require("neotree-favorites.component")(config, node, state)
        end,
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

    ["neotree-favorites"] = {
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
