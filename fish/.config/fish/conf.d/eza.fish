# ~/.config/fish/conf.d/eza.fish

# 1. Настраиваем цвета (используем vivid с темой catppuccin-mocha)
# -x делает переменную экспортируемой (чтобы eza её видела)
if type -q vivid
    set -gx LS_COLORS (vivid generate catppuccin-mocha)
end

# 2. Определяем параметры.
# ВАЖНО: используем -g (global), чтобы функции видели эту переменную
set -g eza_params --icons --group-directories-first --git --time-style=long-iso

# --- ОБЕРТКИ ---

# ls: Просто список
function ls --wraps eza
    eza $eza_params $argv
end

# ll: Список с деталями
function ll --wraps eza
    eza $eza_params --long --header --group $argv
end

# la: Список с деталями + скрытые файлы
function la --wraps eza
    eza $eza_params --long --header --group --all $argv
end

# lt: Дерево файлов (Tree)
function lt --wraps eza
    eza $eza_params --tree --level=2 $argv
end

# lm: Сортировка по времени изменения
function lm --wraps eza
    eza $eza_params --long --header --sort=modified $argv
end
