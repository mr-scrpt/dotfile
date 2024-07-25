-- local map = function(keys, func, desc)
-- 	vim.keymap.set("n", keys, func, { desc = "BASE: " .. desc })
-- end
local map = function(keys, func, desc, mode)
	mode = mode or "n"
	vim.keymap.set(mode, keys, func, { desc = "BASE: " .. desc })
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

map("<leader><leader>", "<c-^>", "[Leader] File Toggle")
map("<Tab>", ":bnext<CR>", "[T]ab next")
map("<s-Tab>", ":bprev<CR>", "[T]ab prev")

map("<leader>wf", vim.cmd.write, "[W]rite File")
map("<leader>wa", ":wa<CR>", "[W]rite All File")

map("<leader>qb", vim.cmd.q, "[Q]uit [B]uffer with close panel")
map("<leader>qa", ":qa!<CR>", "[Q]uit [A]ll")
map("<leader>qd", ":bdelete<CR>", "[Q]uit and [D]elete buffer")
map("<leader>qf", ":cclose<CR>", "[Q]uit [Q]uickfix")

-- map( "<leader>ba", ":%bd|e#<CR>", "[B]uffer [A]ll")
-- vim.cmd([[
--   command! BufCurOnly execute '%bdelete|edit#|bdelete#'
--   nnoremap <leader>qb :BufCurOnly<CR>
-- ]])

-- vim.cmd([[
--   nnoremap  <silent>   <tab>  :if &modifiable && !&readonly && &modified <CR> :write<CR> :endif<CR>:bnext<CR>
--   nnoremap  <silent> <s-tab>  :if &modifiable && !&readonly && &modified <CR> :write<CR> :endif<CR>:bprevious<CR>
-- ]])
--
--
vim.cmd([[
    function! Numbers()
      call search('\d\([^0-9\.]\|$\)', 'cW')
      normal v
      call search('\(^\|[^0-9\.]\d\)', 'becW')
    endfunction
    xnoremap id :<C-u>call Numbers()<CR>
    onoremap id :normal vin<CR>
]])

-- replace word
map("<leader>rw", ":%s/<c-r><c-w>//gc<left><left><left>", "[R]eplace [W]ord Text")

-- vim.cmd([[
-- " Use one of the following to define the camel characters.
-- " Stop on capital letters.
-- let g:camelchar = "A-Z"
-- " Also stop on numbers.
-- let g:camelchar = "A-Z0-9"
-- " ]])
-- to next capi letter
-- Tabs

-- vim.keymap.set("n", "<leader>b", "/\\u<CR>:nohlsearch<CR>")

map("<ESC>", ":noh<return><esc>", "[ESC] Clear highlight")

-- -- Rename word in buffer
-- vim.cmd([[
--
--
-- nnoremap <leader>lw *<c-o>cgn
-- " nnoremap c# #<C-o>cgn
-- ]])

-- QuickFix list

map("<leader>j", "<cmd>cnext<CR>zz", "[J] Jump Next")
map("<leader>k", "<cmd>cprev<CR>zz", "[K] Jump Prev")
-- NeoTree
-- map("<leader>e", ":Neotree float reveal<CR>", "NeoTree [E]xplore")
-- map("<leader>E", ":Neotree right reveal<CR>", "NeoTree [E]xplore Right")
-- map("<leader>o", ":Neotree float git_status<CR>", "NeoTree [O]pen Git Status")

-- Navigation
map("<c-k>", ":wincmd k<CR>", "[K] Jump top split")
map("<c-j>", ":wincmd j<CR>", "[J] Jump bottom split")
map("<c-h>", ":wincmd h<CR>", "[H] Jump left split")
map("<c-l>", ":wincmd l<CR>", "[L] Jump right split")

map("<leader>ml", "<C-w>L", "[M]ove [L]eft")
map("<leader>mh", "<C-w>H", "[M]ove Right")

map("<S-k>", "<C-u>zz", "Scroll up center", { "n", "v" })
map("<S-j>", "<C-d>zz", "Scroll down center", { "n", "v" })

-- vim.keymap.set({ "n", "v" }, "H", "^")
map("H", "^", "Go to start of line", { "n", "v" })
-- vim.keymap.set({ "n", "v" }, "L", "$")
map("L", "$", "Go to end of line", { "n", "v" })

-- vim.keymap.set("n", "n", "nzzzv")
map("n", "Nzzzv", "Next search result", { "n", "v" })
-- vim.keymap.set("n", "N", "Nzzzv")
map("N", "Nzzzv", "Previous search result", { "n", "v" })
-- vim.keymap.set("n", "<leader>/", ":CommentToggle<CR>")

-- Splits
map("sV", vim.cmd.split, "[S]plit [H]orizontally")
map("sv", vim.cmd.vs, "[S]plit [V]ertically")
-- vim.keymap.set("n", "VV", ":split<CR>")

-- Other
-- vim.keymap.set("n", "<leader>w", ":w<CR>")
-- vim.keymap.set("n", "<leader>x", ":BufferLinePickClose<CR>")
-- vim.keymap.set("n", "<leader>X", ":BufferLineCloseRight<CR>")
-- vim.keymap.set("n", "<leader>s", ":BufferLineSortByTabs<CR>")
-- vim.keymap.set("i", "jj", "<Esc>")

-- vim.keymap.set("n", "<leader>H", ":nohlsearch<CR>")

-- Terminal
map("<leader>tf", ":ToggleTerm direction=float<CR>", "[T]erminal [F]loat")
map("<leader>th", ":ToggleTerm direction=horizontal<CR>", "[T]erminal [H]orizontal")
map("<leader>tv", ":ToggleTerm direction=vertical size=40<CR>", "[T]erminal [V]ertical")

-- next greatest remap ever : asbjornHaland
map("<leader>y", [["+y]], "[Y]ank to clipboard", { "n", "v" })
map("<leader>Y", [["+Y]], "[Y]ank line to clipboard")

map("<leader>x", [["+x]], "[X] Cut to clipboard", { "n", "v" })
map("<leader>X", [["+X]], "[X] Cut line to clipboard")

map("<Esc><Esc>", "<C-\\><C-n>", "[Esc] Exit terminal mode", "t")
