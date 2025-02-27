return {
  -- "mr-scrpt/wonderstyler",
  dir = "~/Project/solution/nvim/plugins/wonderstyler/",
  keys = {
    { "<leader>wg", ":WonderStylerGenerate<CR>", desc = "Style Generate [Wonderstyler]" },
    { "<leader>wl", ":WonderStylerShow<CR>", desc = "Style Show [Wonderstyler]" },
  },
  config = function()
    require("wonderstyler").setup()
  end,
}
