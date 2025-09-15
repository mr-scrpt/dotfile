-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_blink_main = false
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
local opt = vim.opt

opt.clipboard = ""
opt.laststatus = 3
opt.showmode = false

vim.g.ai_cmp = false
-- vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
--   virtual_text = false,
-- })

vim.diagnostic.config({
  virtual_text = false,
})

-- DEBUG
-- Максимальный уровень логирования
vim.g.loaded_python3_provider = 0 -- отключить python если не нужен
vim.g.loaded_ruby_provider = 0 -- отключить ruby если не нужен
vim.g.loaded_perl_provider = 0 -- отключить perl если не нужен

-- Включить подробное логирование
vim.env.NVIM_LOG_LEVEL = "TRACE" -- или 'DEBUG'
vim.env.NVIM_LOG_FILE = vim.fn.expand("~/.cache/nvim/debug.log")

-- Дополнительно включить verbose режим
vim.o.verbose = 15 -- максимальный уровень
vim.o.verbosefile = vim.fn.expand("~/.cache/nvim/verbose.log")
