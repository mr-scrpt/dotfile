#!/usr/bin/env bash

# Флаг для отслеживания, была ли произведена очистка
cleaned=0

# Список возможных путей
possible_paths=(
    "$HOME/.tmux/resurrect"
    "$HOME/.local/share/tmux/resurrect"
    "$HOME/.config/tmux/resurrect"
)

# 1. Удаляем файлы сохранений
for p in "${possible_paths[@]}"; do
    if [ -d "$p" ]; then
        rm -rf "$p"
        mkdir -p "$p"
        cleaned=1
    fi
done

# 2. Убиваем сервер Tmux, чтобы сбросить состояние из памяти
# 2>/dev/null скрывает ошибку, если сервер и так не запущен
tmux kill-server 2>/dev/null

# 3. Отправляем уведомление
if [ "$cleaned" -eq 1 ]; then
    notify-send -h string:x-canonical-private-synchronous:sys-notify "Tmux" "🧹 Файлы удалены, сервер перезапущен"
else
    # Даже если файлов не было, мы все равно убили сервер для надежности
    notify-send -u low -h string:x-canonical-private-synchronous:sys-notify "Tmux" "Файлы не найдены, сервер остановлен"
fi
