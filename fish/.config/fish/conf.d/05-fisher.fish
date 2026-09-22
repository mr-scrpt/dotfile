# Плагины fisher ставятся ВНЕ ~/.config/fish: эта папка целиком наша и
# свёрнута стоу в один симлинк на репозиторий. Без этого fisher писал бы
# плагины прямо в дотфайлы.
set -gx fisher_path $HOME/.local/share/fisher

# Функции и автодополнения плагинов лежат там же
set -p fish_function_path $fisher_path/functions
set -p fish_complete_path $fisher_path/completions

for f in $fisher_path/conf.d/*.fish
    test -r $f; and source $f
end
