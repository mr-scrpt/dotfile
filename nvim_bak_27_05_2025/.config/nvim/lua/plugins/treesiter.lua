return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<BS>", desc = "Decrement Selection", mode = "x" },
        { "<C-i>", desc = "Increment Selection", mode = { "x", "n" } },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    keys = {
      { "<C-i>", desc = "Increment Selection" },
      { "<bs>", desc = "Decrement Selection", mode = "x" },
    },
    opts = {
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-i>",
          node_incremental = "<C-i>",
          scope_incremental = false,
          node_decremental = "<A-i>",
        },
      },
      ensure_installed = {
        "bash",
        "c",
        "diff",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "jsonc",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "printf",
        "python",
        "query",
        "regex",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
        "css",
        "scss",
        "pug",
      },
    },
  },
}
