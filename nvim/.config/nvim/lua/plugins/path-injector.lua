--  lua/plugins/path-injector.lua
return {
  {

    dir = "~/Hellkitchen/solution/nvim/path_injector.nvim",

    event = "VeryLazy",

    config = function()
      require("path-injector").setup()
    end,
  },
}
