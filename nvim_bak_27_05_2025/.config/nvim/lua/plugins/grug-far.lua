return {
  "MagicDuck/grug-far.nvim",
  opts = { headerMaxWidth = 80 },
  -- lazy = false,
  cmd = "GrugFar",
  keys = {
    {
      "<leader>srA",
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
      desc = "S&R in !ALL! files",
    },
    {
      "<leader>srfcs",
      function()
        local grug = require("grug-far")
        local ext = vim.fn.expand("<cword>")
        local path = vim.fn.expand("%")
        grug.open({ prefills = { search = ext, paths = path } })
      end,
      mode = { "n", "v" },
      desc = "S&R current word in current file",
    },
    {
      "<leader>srfca",
      function()
        local grug = require("grug-far")
        local ext = vim.fn.expand("%")
        grug.open({ prefills = { paths = ext } })
      end,
      mode = { "n", "v" },
      desc = "S&R in current file",
    },
  },
}
