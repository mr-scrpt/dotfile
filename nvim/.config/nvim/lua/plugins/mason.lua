return {
  "mason-org/mason.nvim",
  -- opts_extend = { "ensure_installed" },
  opts = {
    ui = {
      border = "rounded",
    },
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
