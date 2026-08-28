return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "MagicDuck/grug-far.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
    "johmsalas/text-case.nvim",
    {
      "s1n7ax/nvim-window-picker",
      config = function()
        require("window-picker").setup({
          autoselect_one = true,
          include_current = false,
          filter_rules = {
            bo = {
              filetype = { "neo-tree", "neo-tree-popup", "notify" },
              buftype = { "terminal", "quickfix" },
            },
          },
          other_win_hl_color = "#e35e4f",
        })
      end,
    },
  },

  -- [[ НАСТРОЙКИ ]] --
  opts = {
    auto_expand_width = true,

    event_handlers = {
      {
        event = "neo_tree_buffer_enter",
        handler = function()
          vim.opt_local.relativenumber = true
        end,
      },
    },

    filesystem = {
      bind_to_cwd = false,
      check_gitignore_in_search = false,
      find_by_full_path_words = false,
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },

      -- [[ НАСТРОЙКИ ФИЛЬТРАЦИИ И ПОИСКА ]] --
      -- Это важно для fuzzy_finder, чтобы он не закрывался сам по себе
      use_libuv_file_watcher = true,

      window = {
        mappings = {
          -- [[ ИСПРАВЛЕННЫЙ ПОИСК ]]
          -- Используем "fuzzy_finder".
          -- Это создаст поиск, который ищет файлы в дереве по мере ввода.
          ["/"] = "fuzzy_finder",

          -- Для поиска только по папкам (иногда полезно)
          ["D"] = "fuzzy_finder_directory",

          -- Сбросить фильтр (вернуть вид всех файлов) можно нажав Esc в поиске
          -- или используя эту комбинацию, если фильтр залип:
          ["f"] = "filter_on_submit",
          ["<C-x>"] = "clear_filter",

          -- Превью (ручное)
          ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
          ["l"] = "focus_preview",
          ["<Esc>"] = "cancel",
        },

        -- Подсказка: В режиме поиска (fuzzy_finder):
        -- Стрелка вниз/вверх: выбор файла
        -- Enter: открыть файл
      },

      renderers = {
        directory = {
          { "indent" },
          { "icon" },
          { "current_filter" },
          {
            "container",
            content = {
              { "name", zindex = 10 },
              { "favorite_indicator", zindex = 10 },
              { "symlink_target", zindex = 10, highlight = "NeoTreeSymbolicLinkTarget" },
              { "clipboard", zindex = 10 },
              { "diagnostics", errors_only = true, zindex = 20, align = "right", hide_when_expanded = true },
              { "git_status", zindex = 10, align = "right", hide_when_expanded = true },
              { "file_size", zindex = 10, align = "right" },
              { "type", zindex = 10, align = "right" },
              { "last_modified", zindex = 10, align = "right" },
              { "created", zindex = 10, align = "right" },
            },
          },
        },
        file = {
          { "indent" },
          { "icon" },
          {
            "container",
            content = {
              { "name", zindex = 10 },
              { "favorite_indicator", zindex = 10 },
              { "symlink_target", zindex = 10, highlight = "NeoTreeSymbolicLinkTarget" },
              { "clipboard", zindex = 10 },
              { "diagnostics", zindex = 20, align = "right" },
              { "git_status", zindex = 10, align = "right" },
              { "file_size", zindex = 10, align = "right" },
              { "type", zindex = 10, align = "right" },
              { "last_modified", zindex = 10, align = "right" },
              { "created", zindex = 10, align = "right" },
            },
          },
        },
      },
    },

    default_component_configs = {
      container = { enable_character_fade = true },
      indent = {
        indent_size = 2,
        padding = 1,
        with_markers = true,
        indent_marker = "│",
        last_indent_marker = "└",
        highlight = "NeoTreeIndentMarker",
        with_expanders = nil,
        expander_collapsed = "",
        expander_expanded = "",
        expander_highlight = "NeoTreeExpander",
      },
      icon = {
        folder_closed = "",
        folder_open = "",
        folder_empty = "󰜌",
        default = "*",
        highlight = "NeoTreeFileIcon",
      },
      modified = { symbol = "[+]", highlight = "NeoTreeModified" },
      name = {
        trailing_slash = false,
        use_git_status_colors = true,
        highlight = "NeoTreeFileName",
      },
      git_status = {
        symbols = {
          added = "󰎔 ",
          modified = "󰚰 ",
          deleted = "󱘄 ",
          renamed = "󰑕 ",
          untracked = " ",
          ignored = " ",
          unstaged = " ",
          staged = "",
          conflict = "",
        },
      },
      file_size = { enabled = true, required_width = 64 },
      type = { enabled = true, required_width = 122 },
      last_modified = { enabled = true, required_width = 88 },
      created = { enabled = true, required_width = 110 },
      symlink_target = { enabled = false },
    },

    popup_border_style = "rounded",
    sources = { "filesystem", "buffers", "git_status", "neo-tree-fav" },
    source_selector = {
      winbar = true,
      content_layout = "center",
      sources = {
        { source = "filesystem" },
        { source = "buffers" },
        { source = "git_status" },
        { source = "favorites" },
      },
    },
    buffers = {
      follow_current_file = { enabled = true, leave_dirs_open = false },
    },
  },

  config = function(_, opts)
    -- Вспомогательная функция для Grug-far
    local function open_grug_far(prefills)
      local grug_far = require("grug-far")
      if not grug_far.has_instance("explorer") then
        grug_far.open({ instanceName = "explorer" })
      else
        grug_far.open_instance("explorer")
      end
      grug_far.update_instance_prefills("explorer", prefills, false)
    end

    local neotree = require("neo-tree")

    -- Объединяем настройки
    neotree.setup(vim.tbl_deep_extend("force", opts, {
      commands = {
        grug_far_replace = function(state)
          local node = state.tree:get_node()
          local prefills = {
            paths = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
              or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h")),
          }
          open_grug_far(prefills)
        end,
        grug_far_replace_visual = function(state, selected_nodes, callback)
          local paths = {}
          for _, node in pairs(selected_nodes) do
            local path = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
              or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h"))
            table.insert(paths, path)
          end
          local prefills = { paths = table.concat(paths, "\n") }
          open_grug_far(prefills)
        end,
        system_open = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          vim.fn.jobstart({ "xdg-open", path }, { detach = true })
        end,
      },

      window = {
        mappings = {
          ["R"] = function(state)
            local path = state.tree:get_node().path
            require("grug-far").open({ prefills = { paths = path } })
          end,
          ["b"] = function()
            vim.api.nvim_exec("Neotree focus buffers float", true)
          end,
          ["o"] = "system_open",
          ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
          ["l"] = "focus_preview",
          ["<Esc>"] = "cancel",
        },
      },
    }))

    vim.keymap.set("n", "<leader>e", ":Neotree float reveal<CR>", { desc = "NeoTree Float" })
    vim.keymap.set("n", "<leader>E", ":Neotree right reveal<CR>", { desc = "NeoTree Right" })
  end,
}
