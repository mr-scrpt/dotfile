-- lazy.nvim
return {
  "m4xshen/hardtime.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },

  opts = {
    disabled_keys = {
      ["<Left>"] = { "n" },
      ["<Right>"] = { "n" },
      ["l"] = { "n" },
      ["h"] = { "n" },
      ["<Up>"] = { "n" },
      ["<Down>"] = { "n" },
      ["k"] = { "n" },
      ["j"] = { "n" },
    },
  },
}
