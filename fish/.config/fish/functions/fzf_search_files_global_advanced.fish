function fzf_search_files_global_advanced
    # --- Шаг 1: Выбор области поиска ---
    set -l search_area (echo -e "Домашняя директория (~)\nВесь корень (/)\nТекущая директория (.)" | fzf --prompt="🌐 Выберите область поиска: ")

    set -l search_path
    switch "$search_area"
        case "Домашняя директория (~)"
            set search_path $HOME
        case "Весь корень (/)"
            set search_path /
        case "Текущая директория (.)"
            set search_path .
        case '*'
            commandline -f repaint
            return
    end

    # --- Шаг 2: Выбор, искать ли скрытые файлы ---
    set -l search_hidden_choice (echo -e "Да, искать скрытые\nНет, не искать" | fzf --prompt="👻 Искать скрытые файлы и папки? ")

    # --- Шаг 3: Ввод маски для поиска ---
    read -P "🔎 Введите маску поиска (Enter для всех файлов): " file_mask

    # --- Собираем команду fd ---
    set -l search_pattern "*" # Теперь по умолчанию ищем всё через glob-звездочку
    if test -n "$file_mask"
        set search_pattern "$file_mask"
    end

    set -l fd_exclusions "--exclude .git"

    if test "$search_path" = /
        set fd_exclusions "$fd_exclusions --exclude /mnt --exclude /media --exclude /proc --exclude /sys --exclude /dev --exclude /run --exclude /var --exclude lost+found"
    end

    # ИСПРАВЛЕНО: Добавлен флаг --glob, чтобы маски работали правильно
    set -l fd_cmd "fd --type f --follow --glob $fd_exclusions"

    switch "$search_hidden_choice"
        case "Да, искать скрытые"
            set fd_cmd "$fd_cmd --hidden"
        case "Нет, не искать"
            # No-op
        case '*'
            commandline -f repaint
            return
    end

    # --- Шаг 4: Выполнение поиска и выбор файла ---
    set -l file (eval "$fd_cmd '$search_pattern' '$search_path'" | fzf --prompt="🔍 Поиск '$search_pattern'..." --preview 'bat --color=always --style=numbers --line-range=:500 {}' 2>/dev/null)

    if test -n "$file"
        set -l file_dir (dirname "$file")
        set -l file_name (basename "$file")

        cd "$file_dir"
        commandline -i "$file_name"
    end

    commandline -f repaint
end
