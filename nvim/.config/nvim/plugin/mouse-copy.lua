-- Copy on mouse select, as herdr and Ghostty do: releasing a mouse selection
-- (drag, double-click word, triple-click line) yanks it to the system
-- clipboard. Neovim has no option for this ('clipboard=autoselect' is not
-- implemented, neovim#2325); this is the mapping from :h faq.
for _, lhs in ipairs({ "<LeftRelease>", "<2-LeftRelease>", "<3-LeftRelease>" }) do
  vim.keymap.set("x", lhs, '"+y', { desc = "Copy mouse selection to clipboard" })
end
