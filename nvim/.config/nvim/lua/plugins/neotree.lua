local function copy_path(state)
  local node = state.tree:get_node()
  if not node then
    vim.notify("Could not get node from neo-tree", vim.log.levels.WARN)
    return
  end
  local filepath = node:get_id()
  local filename = node.name
  local modify = vim.fn.fnamemodify

  local results = {
    filepath,
    modify(filepath, ":."),
    modify(filepath, ":~"),
    filename,
    modify(filename, ":r"),
    modify(filename, ":e"),
  }

  vim.ui.select({
    "1. Absolute path: " .. results[1],
    "2. Path relative to CWD: " .. results[2],
    "3. Path relative to HOME: " .. results[3],
    "4. Filename: " .. results[4],
    "5. Filename without extension: " .. results[5],
    "6. Extension of the filename: " .. results[6],
  }, { prompt = "Choose to copy to clipboard:" }, function(choice)
    if choice then
      local i = tonumber(choice:sub(1, 1))
      if i and results[i] then
        local result = results[i]
        -- Используем регистр '+' для копирования в системный буфер обмена
        vim.fn.setreg("+", result)
        vim.notify("Copied to system clipboard: " .. result)
      else
        vim.notify("Invalid selection", vim.log.levels.WARN)
      end
    else
      vim.notify("Selection cancelled")
    end
  end)
end

return {
  "nvim-neo-tree/neo-tree.nvim",

  branch = "v3.x",
  dependencies = {
    "MagicDuck/grug-far.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
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
  },

  config = function(_, opts)
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
    neotree.setup({
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
          local a = vim.loop.new_async(vim.schedule_wrap(function()
            local handle
            local success
            if vim.fn.has("mac") == 1 then
              handle = vim.fn.jobstart({ "open", path }, { detach = true })
              success = handle > 0
            elseif vim.fn.has("linux") == 1 then
              handle = vim.fn.jobstart({ "xdg-open", path }, { detach = true })
              success = handle > 0
            elseif vim.fn.has("win32") == 1 then
              -- On Windows, we might want to open the containing folder in explorer
              local p = vim.fn.fnamemodify(path, ":h")
              handle = vim.fn.jobstart({ "explorer", p }, { detach = true })
              success = handle > 0
            end

            if not success then
              vim.notify("Failed to open " .. path, vim.log.levels.ERROR)
            end
          end))
          a:send()
        end,
      },
      window = {
        mappings = {
          ["R"] = function(state)
            local node = state.tree:get_node()
            if node then
              require("grug-far").open({ prefills = { paths = node.path } })
            end
          end,
          ["b"] = function()
            vim.api.nvim_exec("Neotree focus buffers float", true)
          end,
          ["o"] = "system_open",
          ["Y"] = copy_path, -- Наша обновленная функция
        },
      },
      popup_border_style = "rounded",
      sources = { "filesystem", "buffers", "git_status" },
      source_selector = {
        winbar = true,
        content_layout = "center",
        sources = {
          { source = "filesystem" },
          { source = "buffers" },
          { source = "git_status" },
        },
      },
      buffers = {
        follow_current_file = {
          enabled = true,
          leave_dirs_open = false,
        },
      },
      filesystem = {
        check_gitignore_in_search = false,
        find_by_full_path_words = false,
      },
      default_component_configs = {
        container = {
          enable_character_fade = true,
        },
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
        modified = {
          symbol = "[+]",
          highlight = "NeoTreeModified",
        },
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
        file_size = {
          enabled = true,
          required_width = 64,
        },
        type = {
          enabled = true,
          required_width = 122,
        },
        last_modified = {
          enabled = true,
          required_width = 88,
        },
        created = {
          enabled = true,
          required_width = 110,
        },
        symlink_target = {
          enabled = false,
        },
      },
    })

    local map = function(keys, func, desc, mode)
      mode = mode or "n"
      vim.keymap.set(mode, keys, func, { desc = "NeoTree: " .. desc, noremap = true, silent = true })
    end
    map("<leader>e", ":Neotree float reveal<CR>", "NeoTree [E]xplore")
    map("<leader>E", ":Neotree right reveal<CR>", "NeoTree [E]xplore Right")
  end,
}
