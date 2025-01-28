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

-- -- Функция для извлечения имен классов из строки
-- local function extract_class_names(line)
-- 	local class_names = {}
-- 	-- Поиск class="..."
-- 	for class_attr in string.gmatch(line, 'class%s*=%s*"([^"]+)"') do
-- 		-- Разделение имен классов по пробелам
-- 		for class_name in string.gmatch(class_attr, "%S+") do
-- 			table.insert(class_names, class_name)
-- 		end
-- 	end
-- 	-- Поиск class='...'
-- 	for class_attr in string.gmatch(line, "class%s*=%s*'([^']+)'") do
-- 		for class_name in string.gmatch(class_attr, "%S+") do
-- 			table.insert(class_names, class_name)
-- 		end
-- 	end
-- 	return class_names
-- end
--
-- -- Основная функция для генерации SCSS-скелета
-- function _G.generate_scss_skeleton()
-- 	-- Получение выделенного текста
-- 	local s_start = vim.fn.getpos("'<")
-- 	local s_end = vim.fn.getpos("'>")
-- 	local lines = vim.fn.getline(s_start[2], s_end[2])
--
-- 	-- Если выделена одна строка, корректируем колонки
-- 	if #lines == 1 then
-- 		local start_col = s_start[3]
-- 		local end_col = s_end[3]
-- 		lines[1] = string.sub(lines[1], start_col, end_col)
-- 	end
--
-- 	-- Сбор имен классов
-- 	local class_set = {}
-- 	for _, line in ipairs(lines) do
-- 		local class_names = extract_class_names(line)
-- 		for _, class_name in ipairs(class_names) do
-- 			class_set[class_name] = true
-- 		end
-- 	end
--
-- 	-- Определение базового класса
-- 	local base_classes = {}
-- 	for class_name, _ in pairs(class_set) do
-- 		if not string.find(class_name, "__") then
-- 			table.insert(base_classes, class_name)
-- 		end
-- 	end
--
-- 	local base_class = nil
-- 	if #base_classes == 1 then
-- 		base_class = base_classes[1]
-- 	else
-- 		-- Если несколько базовых классов, выбираем первый из HTML
-- 		for _, line in ipairs(lines) do
-- 			local class_names = extract_class_names(line)
-- 			for _, class_name in ipairs(class_names) do
-- 				if not string.find(class_name, "__") then
-- 					base_class = class_name
-- 					break
-- 				end
-- 			end
-- 			if base_class then
-- 				break
-- 			end
-- 		end
-- 	end
--
-- 	if not base_class then
-- 		-- Если базовый класс не найден, берем первый класс
-- 		for class_name, _ in pairs(class_set) do
-- 			base_class = class_name
-- 			break
-- 		end
-- 	end
--
-- 	-- Генерация SCSS-скелета
-- 	local scss_lines = {}
-- 	table.insert(scss_lines, "." .. base_class .. " {")
--
-- 	-- Сбор модификаторов и других классов
-- 	local modifiers = {}
-- 	local other_classes = {}
--
-- 	for class_name, _ in pairs(class_set) do
-- 		if class_name ~= base_class then
-- 			local prefix = base_class
-- 			if string.sub(class_name, 1, #prefix) == prefix then
-- 				local modifier = string.sub(class_name, #prefix + 1)
-- 				table.insert(modifiers, modifier)
-- 			else
-- 				table.insert(other_classes, class_name)
-- 			end
-- 		end
-- 	end
--
-- 	-- Добавление модификаторов
-- 	for _, modifier in ipairs(modifiers) do
-- 		table.insert(scss_lines, "  &" .. modifier .. " {")
-- 		table.insert(scss_lines, "  }")
-- 		table.insert(scss_lines, "")
-- 	end
--
-- 	-- Закрытие базового класса
-- 	table.insert(scss_lines, "}")
-- 	table.insert(scss_lines, "")
--
-- 	-- Добавление других классов
-- 	for _, class_name in ipairs(other_classes) do
-- 		table.insert(scss_lines, "." .. class_name .. " {")
-- 		table.insert(scss_lines, "}")
-- 		table.insert(scss_lines, "")
-- 	end
--
-- 	-- Объединение строк SCSS
-- 	local scss_text = table.concat(scss_lines, "\n")
--
-- 	-- Копирование в буфер обмена
-- 	vim.fn.setreg("+", scss_text)
--
-- 	-- Вывод сообщения
-- 	print("SCSS скелет скопирован в буфер обмена.")
-- end
--
-- -- Привязка функции к сочетанию клавиш в визуальном режиме
-- vim.api.nvim_set_keymap("v", "<Leader>ms", ":<C-u>lua generate_scss_skeleton()<CR>", { noremap = true, silent = true })
