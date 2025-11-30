local Utils = require("custom.utils")
local INITIAL_CWD = vim.uv.cwd()

return {
  {
    "antosha417/nvim-lsp-file-operations",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neo-tree/neo-tree.nvim", -- makes sure that this loads after Neo-tree.
    },
    config = function()
      require("lsp-file-operations").setup()
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",

    dependencies = {
      "MagicDuck/grug-far.nvim",
      "johmsalas/text-case.nvim",
      { dir = "/home/mr/Hellkitchen/solution/nvim/neotree-favorites.nvim" },
    },

    keys = {
      {
        "<leader>e",
        function()
          require("neo-tree.command").execute({
            toggle = true,
            position = "float",
            reveal = true,
            dir = INITIAL_CWD,
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
      close_if_last_window = false,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = false,
      commands = {
        grug_far_replace = Utils.grug_far_replace,
        grug_far_replace_visual = Utils.grug_far_replace_visual,
        
        -- Favorites commands
        add_to_flat_favorites = function(state)
          require("neotree-favorites.commands").add_to_flat_favorites(state)
        end,
        remove_from_flat_favorites = function(state)
          require("neotree-favorites.commands").remove_from_flat_favorites(state)
        end,
        toggle_flat_favorite = function(state)
          require("neotree-favorites.commands").toggle_flat_favorite(state)
        end,
        show_favorites_info = function()
          require("neotree-favorites.info").show_project_info()
        end,
        clear_all_flat_favorites = function(state)
          require("neotree-favorites.commands").clear_all_flat_favorites(state)
        end,
        remove_invalid_favorites = function(state)
          require("neotree-favorites.commands").remove_invalid_favorites(state)
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
          flat_favorite_indicator = function(config, node, state)
            return require("neotree-favorites.component")(config, node, state)
          end,
        },
        window = {
          mappings = {
            -- Favorites commands (работают в filesystem view)
            ["s"] = "toggle_flat_favorite",  -- Toggle favorite для текущего файла
            ["I"] = "show_favorites_info",    -- Показать инфо об избранном
            -- NOTE: "w" = стандартный "open_with_window_picker", не переопределяем
            -- Для flat_favorites view используйте "X" для очистки всех
          },
          fuzzy_finder_mappings = {
            ["<CR>"] = function(state, _)
              if state and state.name == "flat_favorites" then
                require("neotree-favorites").reset_search(state, true, true)
              else
                require("neo-tree.sources.filesystem").reset_search(state, true, true)
              end
            end,
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
        use_libuv_file_watcher = true,
        window = {
          mappings = {
            -- Search mappings
            ["/"] = "fuzzy_finder",
            ["#"] = "fuzzy_sorter",
            ["D"] = "fuzzy_finder_directory",
            ["f"] = "filter_on_submit",
            ["<c-x>"] = "clear_filter",
            
            -- Favorites management
            ["s"] = "remove_invalid_favorites",  -- Remove deleted/moved paths
            ["S"] = "toggle_flat_favorite",      -- Toggle favorite for current node
            ["X"] = "clear_all_flat_favorites",  -- Clear all favorites
            ["I"] = "show_favorites_info",       -- Show favorites info
            ["H"] = "toggle_hidden",             -- Toggle gitignored/hidden files
          },
          -- fuzzy_finder_mappings наследуются из init.lua (filesystem defaults)
          -- Enter НЕ мапится здесь - обрабатывается через on_submit в filter.lua
        },
        renderers = {
          directory = {
            { "indent" },
            { "icon", use_filtered_colors = true },
            { "current_filter" },
            { "name", use_filtered_colors = true },
            { "filtered_by" },  -- Показывать статус (gitignored, dotfile, etc)
          },
          file = {
            { "indent" },
            { "icon", use_filtered_colors = true },
            { "name", use_git_status_colors = true, use_filtered_colors = true },
            { "filtered_by" },  -- Показывать статус (gitignored, dotfile, etc)
            { "git_status" },
          },
        },
      },
    },
  },
}
