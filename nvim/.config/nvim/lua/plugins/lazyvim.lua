-- return {
--   "LazyVim/LazyVim",
--   keys = {
--     { "<leader>l", false },
--   },
-- }
-- return {
return {

  "LazyVim/LazyVim",
  opts = {
    defaults = {
      keymaps = {
        { "<leader>l", false },
        { "j", false },
        { "k", false },
        { "<Up>", false },
        { "<Down>", false },
      },
      -- keymaps = false,
    },
  },
}
