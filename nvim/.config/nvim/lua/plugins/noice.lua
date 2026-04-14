-- TEST: мульти-файл раунд 2 (файл 2)
-- ~/.config/nvim/lua/plugins/noice.lua
return {
  "folke/noice.nvim",
  opts = {
    lsp = {
      signature = {
        enabled = true, -- можно поставить false чтобы отключить
        auto_open = {
          enabled = true,
          trigger = true,
          luasnip = true,
        },
      },
    },
  },
}
-- return {
--   -- "folke/noice.nvim",
--   -- event = "VeryLazy",
--   -- opts = function(_, opts)
--   --   opts.presets.lsp_doc_border = true
--   --   return opts -- <-- Лучше всегда возвращать opts
--   -- end,
-- }
