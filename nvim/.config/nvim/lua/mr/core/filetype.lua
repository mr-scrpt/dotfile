vim.cmd([[
  augroup FileTypeRasi
    autocmd!
    autocmd BufRead,BufNewFile *.rasi set filetype=css
  augroup END
]])
