# Навигация и файлы. Цвета не задаём: eza без LS_COLORS берёт палитру
# терминала, а её рисует активная тема Omarchy.

set -g eza_params --icons --group-directories-first --git --time-style=long-iso

function ls --wraps eza --description 'список'
    eza $eza_params $argv
end

function ll --wraps eza --description 'список с деталями'
    eza $eza_params --long --header --group $argv
end

function la --wraps eza --description 'детали + скрытые'
    eza $eza_params --long --header --group --all $argv
end

function lt --wraps eza --description 'дерево на 2 уровня'
    eza $eza_params --tree --level=2 $argv
end

function lm --wraps eza --description 'по времени изменения'
    eza $eza_params --long --header --sort=modified $argv
end

# cd через zoxide: `cd dotfile` прыгает в ~/Hellkitchen/dotfile откуда угодно
function zd --description 'cd с zoxide'
    if test (count $argv) -eq 0
        builtin cd ~
        and return
    else if test -d $argv[1]
        builtin cd -- $argv[1]
    else if functions -q z
        # z появляется только из `zoxide init fish`, т.е. в интерактивной сессии
        z $argv
        and printf "\U000F17A9 "
        and pwd
        or echo "Error: Directory not found"
    else
        builtin cd -- $argv
    end
end

function cd --wraps zd --description 'alias cd=zd'
    zd $argv
end

function .. --description 'на уровень вверх'
    cd ..
end

function ... --description 'на два уровня вверх'
    cd ../..
end

function .... --description 'на три уровня вверх'
    cd ../../..
end

function open --description 'xdg-open в фоне, не держит терминал'
    xdg-open $argv >/dev/null 2>&1 &
end

function y --description 'yazi, при выходе переходит в выбранный каталог'
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if read -z cwd <"$tmp"; and test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
