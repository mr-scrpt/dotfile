# Обёртка ssh: чистит терминал и переподключается при обрыве.
# Порт $OMARCHY_PATH/default/bash/fns/ssh-reconnect
#
# Удалённый tmux/herdr/редактор включает через SSH режимы терминала
# (трекинг мыши, репортинг фокуса, alt-screen), выключить которые может
# только он сам. Если связь рвётся вместо нормального выхода, режимы
# остаются включёнными, и каждое движение мыши засыпает промпт мусором.

function _ssh_disarm --description 'выключить залипшие режимы терминала'
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?1049l\e[?25h'
end

function _ssh_interactive --description 'true, если это интерактивная сессия без удалённой команды'
    set -l value_opts BbcDEeFIiJLlmOoPpQRSWw
    set -l argv_copy $argv
    set -l dest ""
    set -l opts_done ""
    set -l i 1

    while test $i -le (count $argv)
        set -l arg $argv[$i]
        set i (math $i + 1)

        if test -z "$opts_done" -a "$arg" = --
            set opts_done 1
        else if test -z "$opts_done"; and string match -q -- '-?*' $arg
            set -l letters (string sub -s 2 -- $arg)
            set -l n (string length -- $letters)
            for j in (seq 1 $n)
                set -l ch (string sub -s $j -l 1 -- $letters)
                if string match -q -- "*$ch*" $value_opts
                    # Значение либо приклеено (-p2222), либо идёт следующим (-p 2222)
                    test $j -eq $n; and set i (math $i + 1)
                    break
                end
            end
        else if test -z "$dest"
            set dest $arg
        else
            return 1
        end
    end

    test -n "$dest"; or return 1

    # RemoteCommand из ssh_config повторится при реконнекте так же, как
    # позиционная команда. `ssh -G` разрешает конфиг не подключаясь.
    # Если разрешить не удалось — считаем, что команда есть (fail closed).
    set -l resolved (command ssh -G $argv_copy 2>/dev/null); or return 1
    not string match -qri '^remotecommand (?!none$)' -- $resolved
end

function ssh --description 'ssh с очисткой терминала и реконнектом'
    set -l started $SECONDS
    command ssh $argv
    set -l rc $status

    isatty stdout; or return $rc
    _ssh_disarm

    # Реконнект только когда рвётся интерактивная сессия: 255 — это сбой
    # транспорта, но быстрый 255 без установленной сессии означает отказ
    # подключения/аутентификации; удалённая команда может вернуть свой 255
    # неотличимо и повторять её побочные эффекты нельзя; при перенаправленном
    # stdin остаток ввода уйдёт в новый удалённый шелл.
    if test $rc -ne 255; or not isatty stdin; or not _ssh_interactive $argv; or test (math "$SECONDS - $started") -lt 30
        return $rc
    end

    while true
        echo "Connection lost. Reconnecting (Ctrl-C to stop)..."
        sleep 2
        command ssh $argv
        set rc $status
        _ssh_disarm
        test $rc -ne 255; and return $rc
    end
end
