return {
  -- disable builtin snippet support
  { "garymjr/nvim-snippets", enabled = false },
  -- add luasnip
  {
    "L3MON4D3/LuaSnip",
    dependencies = {
      {
        "rafamadriz/friendly-snippets",
        config = function()
          -- Загружаем lua сниппеты
          local snippet_path = vim.fn.stdpath("config") .. "/snippets/snippet.lua"
          dofile(snippet_path)

          -- Загружаем VSCode сниппеты
          require("luasnip.loaders.from_vscode").lazy_load({
            paths = { vim.fn.stdpath("config") .. "/snippets" },
          })
        end,
      },
    },
  },
}
-- return {
--   -- disable builtin snippet support
--   { "garymjr/nvim-snippets", enabled = false },
--
--   -- add luasnip
--   {
--     "L3MON4D3/LuaSnip",
--     dependencies = {
--       {
--         "rafamadriz/friendly-snippets",
--         config = function()
--           -- require("luasnip.loaders.from_vscode").lazy_load()
--           require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
--         end,
--       },
--     },
--   },
-- }
