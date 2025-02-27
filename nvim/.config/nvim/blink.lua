return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      -- add lazydev to your completion providers
      default = { "lazydev" },
      providers = {
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100, -- show at a higher priority than lsp
        },
        -- lsp = {
        --   name = "lsp",
        --   enabled = true,
        --   module = "blink.cmp.sources.lsp",
        --   kind = "LSP",
        --   min_keyword_length = 2,
        --   score_offset = 90, -- the higher the number, the higher the priority
        -- },
        -- codeium = {
        --   name = "Codeium",
        --   enabled = false,
        --   module = "blink.cmp.sources.codeium",
        --   kind = "Codeium",
        --   min_keyword_length = 2,
        --   score_offset = 90, -- the higher the number, the higher the priority
        -- },
      },
    },
  },
}
--   providers = {
--     lsp = {
--       name = "lsp",
--       enabled = true,
--       kind = "LSP",
--       min_keyword_length = 2,
--       score_offset = 90, -- the higher the number, the higher the priority
--     },
--     path = {
--       name = "Path",
--       score_offset = 25,
--       -- When typing a path, I would get snippets and text in the
--       -- suggestions, I want those to show only if there are no path
--       -- suggestions
--       fallbacks = { "buffer" },
--       min_keyword_length = 2,
--       opts = {
--         trailing_slash = false,
--         label_trailing_slash = true,
--         get_cwd = function(context)
--           return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
--         end,
--         show_hidden_files_by_default = true,
--       },
--     },
--     buffer = {
--       name = "Buffer",
--       enabled = true,
--       max_items = 3,
--       min_keyword_length = 4,
--       score_offset = 15, -- the higher the number, the higher the priority
--     },
--     snippets = {
--       name = "snippets",
--       enabled = true,
--       min_keyword_length = 2,
--       max_items = 15,
--       score_offset = 95, -- the higher the number, the higher the priority
--     },
--   },
-- },

-- lazydev
