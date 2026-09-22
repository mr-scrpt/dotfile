# Поиск. Ctrl+R отдан atuin, остальные биндинги fzf.fish настраиваются
# в config.fish (он выполняется после conf.d самого плагина).

function ff --description 'fzf с превью через bat'
    fzf --preview 'bat --style=numbers --color=always {}' $argv
end

function eff --description 'найти и открыть в редакторе'
    set -l file (ff)
    and $EDITOR $file
end

function sff --description 'найти и отправить по scp'
    if test (count $argv) -eq 0
        echo "Usage: sff <destination> (e.g. sff host:/tmp/)"
        return 1
    end

    set -l file (find . -type f -printf '%T@\t%p\n' | sort -rn | cut -f2- | ff)
    if test -n "$file"
        scp $file $argv[1]
    end
end

function killp --description 'убить процесс, слушающий порт (fzf)'
    set -l process_info (lsof -i -P -n | grep LISTEN | fzf --prompt="Выбери процесс для завершения: " --height=40% --layout=reverse)

    if test -z "$process_info"
        set_color yellow
        echo "Отменено"
        set_color normal
        return 1
    end

    set -l pid (echo $process_info | awk '{print $2}')
    set -l process_name (echo $process_info | awk '{print $1}')
    set -l port_info (echo $process_info | awk '{print $9}')

    kill -9 $pid
    set_color green
    echo "Убит процесс $process_name (PID: $pid) на $port_info"
    set_color normal
end
