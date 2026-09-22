status is-interactive; or exit

# vi-режим ставим ПЕРВЫМ: fish_vi_key_bindings стирает все биндинги,
# а atuin и fzf.fish вешают свои поверх.
fish_vi_key_bindings

if command -q mise
    mise activate fish | source
end

if command -q zoxide
    zoxide init fish | source
end

if command -q starship
    starship init fish | source
end

# История — atuin (SQLite: фильтр по каталогу и коду возврата, статистика).
# Меню открывается стрелкой вверх (на первой строке команды) и на Ctrl+R.
if command -q atuin
    atuin init fish | source
end
