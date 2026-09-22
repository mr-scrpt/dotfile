# Переменные, которые в bash даёт $OMARCHY_PATH/default/bash/envs.
# Сессия uwsm экспортирует не всё (EDITOR/TERMINAL/OMARCHY_PATH есть,
# этих пяти нет), поэтому повторяем ровно недостающее.

if not set -q BROWSER
    set -gx BROWSER omarchy-launch-browser
end
set -gx SUDO_EDITOR $EDITOR
set -gx BAT_THEME ansi

# Цветные man-страницы через bat
set -gx MANROFFOPT -c
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Единый вид всех окон fzf
set -gx FZF_DEFAULT_OPTS '--cycle --layout=default --height=90% --preview-window=wrap --marker="*"'

set -g fish_greeting
