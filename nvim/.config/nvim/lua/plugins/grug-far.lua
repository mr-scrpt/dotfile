return {
  "MagicDuck/grug-far.nvim",
  opts = { headerMaxWidth = 80 },
  cmd = "GrugFar",
  keys = {
    {
      "<leader>sra",
      function()
        local grug = require("grug-far")
        local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
        grug.open({
          transient = true,
          prefills = {
            filesFilter = ext and ext ~= "" and "*." .. ext or nil,
          },
        })
      end,
      mode = { "n", "v" },
      desc = "Search and Replace",
    },
    {
      "<leader>srfc",
      function()
        local grug = require("grug-far")
        local ext = vim.fn.expand("<cword>")
        local path = vim.fn.expand("%")
        grug.open({ prefills = { search = ext, paths = path } })
      end,
      mode = { "n", "v" },
      desc = "Search and Replace",
    },
    {
      "<leader>srf",
      function()
        local grug = require("grug-far")
        local ext = vim.fn.expand("%")
        grug.open({ prefills = { paths = ext } })
      end,
      mode = { "n", "v" },
      desc = "Search and Replace",
    },
  },
}
