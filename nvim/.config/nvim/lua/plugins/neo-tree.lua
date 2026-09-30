-- Neo-tree (LazyVim extra editor.neo-tree) opens as a centred float.
-- Only opts/keys here: they merge into LazyVim's spec, so its config()
-- (LSP rename on move, refresh after lazygit) stays intact.
return {
  "nvim-neo-tree/neo-tree.nvim",
  keys = {
    { "<leader>e", "<cmd>Neotree float reveal<cr>", desc = "Explorer NeoTree (float)" },
    { "<leader>E", "<cmd>Neotree right reveal<cr>", desc = "Explorer NeoTree (right)" },
  },
  opts = {
    popup_border_style = "rounded",
    -- metadata columns appear once the window is wide enough
    default_component_configs = {
      file_size = { enabled = true, required_width = 64 },
      last_modified = { enabled = true, required_width = 88 },
      created = { enabled = true, required_width = 110 },
      type = { enabled = true, required_width = 122 },
    },
    window = {
      position = "float",
      mappings = {
        ["l"] = "focus_preview",
        ["P"] = { "toggle_preview", config = { use_float = true } },
        ["o"] = {
          function(state)
            require("lazy.util").open(state.tree:get_node().path, { system = true })
          end,
          desc = "Open with System Application",
        },
        ["R"] = {
          function(state)
            local node = state.tree:get_node()
            local dir = node.type == "directory" and node.path or vim.fn.fnamemodify(node.path, ":h")
            require("grug-far").open({ prefills = { paths = vim.fn.fnameescape(dir) } })
          end,
          desc = "Search/Replace in Dir (grug-far)",
        },
        ["b"] = {
          function()
            require("neo-tree.command").execute({ source = "buffers", position = "float", action = "focus" })
          end,
          desc = "Buffers (float)",
        },
      },
    },
    event_handlers = {
      {
        event = "neo_tree_buffer_enter",
        handler = function()
          vim.opt_local.relativenumber = true
        end,
      },
    },
  },
}
