function killp --description "Интерактивное завершение процесса на порту"
    # Получаем список процессов, слушающих порты, и передаем в fzf
    set -l process_info (lsof -i -P -n | grep LISTEN | fzf --prompt="Выбери процесс для завершения: " --height=40% --layout=reverse)

    # Если процесс выбран (не нажали Esc)
    if test -n "$process_info"
        # Вытаскиваем PID (обычно это второе слово в строке lsof)
        set -l pid (echo $process_info | awk '{print $2}')
        set -l process_name (echo $process_info | awk '{print $1}')
        set -l port_info (echo $process_info | awk '{print $9}')

        kill -9 $pid
        set_color green
        echo "Убит процесс $process_name (PID: $pid) на $port_info"
        set_color normal
    else
        set_color yellow
        echo Отменено
        set_color normal
    end
end
