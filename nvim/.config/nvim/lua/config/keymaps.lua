-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- vim.keymap.del({ "n", "x" }, "k")
-- vim.keymap.del({ "n", "x" }, "j")
-- vim.keymap.del({ "n", "x" }, "<Up>")
-- vim.keymap.del({ "n", "x" }, "<Down>")

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

-- vim.keymap.del({ "n", "v" }, "<S-j>")
-- vim.keymap.del({ "n", "v" }, "J")

-- map({ "v", "n" }, "<S-k>", "<C-u>zz", { desc = "Scroll up center" })
-- map({ "v", "n" }, "<S-j>", "<C-d>zz", { desc = "Scroll down center" })
-- map({ "v", "n" }, "K", "<C-u>zz", { desc = "Scroll up center" })
-- map({ "v", "n" }, "J", "<C-d>zz", { desc = "Scroll down center" })

map("v", "gy", yank_and_comment, { desc = "Comment and yank", silent = true })

map("v", "gy", yank_and_comment, { desc = "Comment and yank", silent = true })

map("n", "<leader>qb", vim.cmd.q, { desc = "[Q]uit [B]uffer with close panel" })
map("n", "<leader>qf", ":cclose<CR>", { desc = "[Q]uit [Q]uickfix" })

map("n", "<leader>wh", "<C-w>x", { desc = "Swap with left window" })
map("n", "<leader>wl", "<C-w>r", { desc = "Swap with right window" })

map("n", "<C-s>", ":wa<CR>", { desc = "[W]rite All File" })

map({ "n", "v" }, "<leader>y", '"+y', { desc = "[Y]ank to clipboard" })
map({ "n", "v" }, "<leader>Y", '"+Y', { desc = "[Y]ank line to clipboard" })

map({ "n", "v" }, "<leader>xx", '"+x', { desc = "[Y]ank to clipboard" })
map({ "n", "v" }, "<leader>XX", '"+X', { desc = "[Y]ank line to clipboard" })

map("n", "<leader>ml", "<C-w>L", { desc = "[M]ove [R]ight" })
map("n", "<leader>mh", "<C-w>H", { desc = "[M]ove [L]eft" })
