-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = LazyVim.safe_keymap_set
local function yank_and_comment()
  local mini_comment = require("mini.comment")

  local mode = vim.api.nvim_get_mode().mode
  if mode:sub(1, 1) == "v" then
    vim.cmd("normal! y")
    vim.cmd("normal! gv")
    mini_comment.operator("visual")
  else
    vim.cmd("normal! yy")
    mini_comment.operator("line")
  end
end

map("v", "gy", yank_and_comment, { desc = "Comment and yank", silent = true })

map("v", "gy", yank_and_comment, { desc = "Comment and yank", silent = true })

map("n", "<leader>qb", vim.cmd.q, { desc = "[Q]uit [B]uffer with close panel" })
map("n", "<leader>qf", ":cclose<CR>", { desc = "[Q]uit [Q]uickfix" })

map("n", "<leader>wh", "<C-w>x", { desc = "Swap with left window" })
map("n", "<leader>wl", "<C-w>r", { desc = "Swap with right window" })

map("n", "<C-s>", ":w<CR>", { desc = "[W]rite All File" })
-- map("n", "<C-s>", ":wa<CR>", { desc = "[W]rite All File" })

map({ "n", "v" }, "<leader>y", '"+y', { desc = "[Y]ank to clipboard" })
map({ "n", "v" }, "<leader>Y", '"+Y', { desc = "[Y]ank line to clipboard" })

map({ "n", "v" }, "<leader>xx", '"+x', { desc = "[Y]ank to clipboard" })
map({ "n", "v" }, "<leader>XX", '"+X', { desc = "[Y]ank line to clipboard" })

map("n", "<leader>ml", "<C-w>L", { desc = "[M]ove [R]ight" })
map("n", "<leader>mh", "<C-w>H", { desc = "[M]ove [L]eft" })

map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })
