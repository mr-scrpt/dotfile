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
  virtual_lines = true,
  -- virtual_lines = { current_line = true },
})

-- local border_style = "rounded"
--
-- -- Hover (нажатие K на переменной/функции)
-- vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
--   border = border_style,
-- })
--
-- -- Signature help (подсказки параметров функции)
-- vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
--   border = border_style,
-- })
--
-- -- Диагностика (ошибки, предупреждения)
-- vim.diagnostic.config({
--   float = {
--     border = border_style,
--   },
-- })
