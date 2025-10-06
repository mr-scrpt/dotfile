return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  -- keys = {
  --   { "<leader>E", "<leader>fe", desc = "Explorer Snacks (root dir)", remap = true },
  --   { "<leader>e", "<leader>fE", desc = "Explorer Snacks (cwd)", remap = true },
  -- },
  opts = {
    picker = {
      ----@class snacks.picker.formatters.Config
      formatters = {
        file = {
          filename_first = true, -- display filename before the file path
        },
      },
      ---@class snacks.picker.previewers.Config
      sources = {
        explorer = {
          auto_close = true,
          float = true,
          layout = {
            preset = "vertical",
          },
        },
      },
    },
    explorer = {},
  },
  -- keys = {
  --   {
  --     "<leader>fe",
  --     function()
  --       -- Snacks.explorer({ cwd = LazyVim.root() })
  --       Snacks.picker.explorer()
  --     end,
  --     desc = "Explorer Snacks (root dir)",
  --   },
  --   {
  --     "<leader>fE",
  --     function()
  --       -- Snacks.explorer()
  --       Snacks.picker.explorer({
  --         cwd = vim.fn.expand("%:p:h"),
  --         auto_close = true,
  --         layout = {
  --           preset = "vertical",
  --         },
  --         float = true,
  --       })
  --     end,
  --     desc = "Explorer Snacks (cwd)",
  --   },
  --   { "<leader>e", "<leader>fe", desc = "Explorer Snacks (root dir)", remap = true },
  --   { "<leader>E", "<leader>fE", desc = "Explorer Snacks (cwd)", remap = true },
  -- },
}
