return {
  "mr-scrpt/chronovimus",
  dependencies = {
    "folke/snacks.nvim",
  },
  lazy = false,
  keys = {
    { "H", ":HistoryBack<CR>", desc = "History Back" },
    { "L", ":HistoryForward<CR>", desc = "History Forward" },
    { "<leader>bl", ":HistoryList<CR>", desc = "History List" },
  },
  config = function()
    require("chronovimus").setup({
      debug = true,
    })
  end,
}
