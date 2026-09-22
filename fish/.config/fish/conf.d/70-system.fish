# Система и сеть — порт fns/{compression,drives,ssh-port-forwarding,rsyncing}

function compress --description 'каталог -> tar.gz'
    set -l dir (string replace -r '/$' '' -- $argv[1])
    tar -czf "$dir.tar.gz" "$dir"
end

function decompress --wraps 'tar -xzf' --description 'распаковать tar.gz'
    tar -xzf $argv
end

function iso2sd --description 'записать ISO на флешку'
    if test (count $argv) -lt 1
        echo "Usage: iso2sd <input_file> [output_device]"
        echo "Example: iso2sd ~/Downloads/ubuntu-25.04-desktop-amd64.iso /dev/sda"
        return 1
    end

    set -l iso $argv[1]
    set -l drive $argv[2]

    if test -z "$drive"
        set -l available_sds (lsblk -dpno NAME | grep -E '/dev/sd')

        if test -z "$available_sds"
            echo "No SD drives found and no drive specified"
            return 1
        end

        set drive (omarchy-drive-select "$available_sds")

        if test -z "$drive"
            echo "No drive selected"
            return 1
        end
    end

    sudo dd bs=4M status=progress oflag=sync if="$iso" of="$drive"
    sudo eject "$drive"
end

# --- проброс SSH-портов ---

function fip --description 'пробросить порты с хоста'
    if test (count $argv) -lt 2
        echo "Usage: fip <host> <port1> [port2] ..."
        return 1
    end
    set -l host $argv[1]
    for port in $argv[2..]
        ssh -f -N -L "$port:localhost:$port" "$host"
        and echo "Forwarding localhost:$port -> $host:$port"
    end
end

function dip --description 'прекратить проброс портов'
    if test (count $argv) -eq 0
        echo "Usage: dip <port1> [port2] ..."
        return 1
    end
    for port in $argv
        if pkill -f "ssh.*-L $port:localhost:$port"
            echo "Stopped forwarding port $port"
        else
            echo "No forwarding on port $port"
        end
    end
end

function lip --description 'активные пробросы'
    pgrep -af "ssh.*-L [0-9]+:localhost:[0-9]+"; or echo "No active forwards"
end

# --- rsync-вотчеры ---

function rsw --description 'синхронизировать каталог при каждом изменении'
    if test (count $argv) -ne 2
        echo "Usage: rsw <source> <destination>"
        return 1
    end
    set -l src (string replace -r '/$' '' -- $argv[1])
    set -l dest $argv[2]
    # Одно SSH-соединение на весь сеанс, чтобы пароль спрашивался один раз
    set -l sockets (test -n "$XDG_RUNTIME_DIR"; and echo $XDG_RUNTIME_DIR; or echo ~/.ssh/sockets)
    mkdir -p "$sockets"
    set -l rsh "ssh -o ControlMaster=auto -o ControlPath=$sockets/rsw-%r@%h:%p -o ControlPersist=yes"
    setsid --fork env RSYNC_RSH="$rsh" bash -c 'rsync -a "$1/" "$2"; while inotifywait -r -q -e modify,create,delete,move "$1"; do rsync -a "$1/" "$2"; done' rsw-watch "$src" "$dest" >/dev/null 2>&1
    echo "Watching $src -> $dest"
end

function lsw --description 'список активных вотчеров'
    set -l found 0
    for line in (pgrep -af 'rsw-watch ')
        set -l rest (string replace -r '.*rsw-watch ' '' -- $line)
        set -l parts (string split ' ' -- $rest)
        echo (string split ' ' -- $line)[1]": $parts[1] -> $parts[2]"
        set found 1
    end
    test $found -eq 1; or echo "No active watches"
end

function dsw --description 'остановить все вотчеры'
    set -l found 0
    for pid in (pgrep -f 'rsw-watch ')
        if kill -- -$pid 2>/dev/null
            echo "Stopped watch (pid $pid)"
            set found 1
        end
    end
    test $found -eq 1; or echo "No active watches"
end
