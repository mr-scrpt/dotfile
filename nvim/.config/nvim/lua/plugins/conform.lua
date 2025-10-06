return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        css = { "stylelint", "prettier" },
        scss = { "stylelint", "prettier" },
        html = { "prettier" },
        php = { "prettier" },
        pug = { "prettier" },
        jade = { "prettier" },
      },
    },
  },
}
