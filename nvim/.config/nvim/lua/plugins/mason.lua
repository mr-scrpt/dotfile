return {
  "williamboman/mason.nvim",
  -- opts_extend = { "ensure_installed" },
  opts = {
    ensure_installed = {
      "vtsls", -- typescript-language-server
      "shfmt",
      "stylelint-lsp",
      "stylelint",
      "html-lsp",
      "css-lsp",
      "tailwindcss-language-server",
      "lua-language-server",
      "emmet-ls",
      "prisma-language-server",
    },
  },
}
