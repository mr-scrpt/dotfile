vim.cmd([[
  augroup FileTypeRasi
    autocmd!
    autocmd BufRead,BufNewFile *.rasi set filetype=css
  augroup END

  autocmd BufRead,BufNewFile *.njk set filetype=html
  autocmd BufRead,BufNewFile *.jade set filetype=pug
]])
