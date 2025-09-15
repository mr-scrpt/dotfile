return {
  { "garymjr/nvim-snippets", enabled = false },
  {
    "L3MON4D3/LuaSnip",
    dependencies = {
      {
        "rafamadriz/friendly-snippets",
        config = function()
          local snippet_path = vim.fn.stdpath("config") .. "/snippets/snippet.lua"
          dofile(snippet_path)

          require("luasnip.loaders.from_vscode").lazy_load({
            paths = { vim.fn.stdpath("config") .. "/snippets" },
          })
        end,
      },
    },
  },
}
