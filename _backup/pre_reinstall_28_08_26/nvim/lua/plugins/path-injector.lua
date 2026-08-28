--  lua/plugins/path-injector.lua
return {
  {
    "mr-scrpt/path_injector.nvim",

    event = "VeryLazy",

    config = function()
      require("path-injector").setup()
    end,
  },
}
