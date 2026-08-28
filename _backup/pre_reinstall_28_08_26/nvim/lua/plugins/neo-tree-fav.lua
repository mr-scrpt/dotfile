--  lua/plugins/neo-tree-fav.lua
return {
  {
    -- GitHub version:
    "mr-scrpt/neo-tree-fav",
    -- Local dev version (uncomment to switch):
    -- dir = "/home/mr/Hellkitchen/solution/nvim/neo-tree-fav",

    dependencies = {
      "nvim-neo-tree/neo-tree.nvim",
    },
    config = function()
      require("neo-tree-fav").setup({
        -- keymap = "<leader>F",          -- default
        -- filesystem_toggle_key = "F",   -- default
        -- indicator = { icon = " ⭐" },  -- default
      })
    end,
  },
}
