#!/usr/bin/env bash

# Флаг для отслеживания, была ли произведена очистка
cleaned=0

# Список возможных путей (аналог set -l possible_paths из fish)
possible_paths=(
    "$HOME/.tmux/resurrect"
    "$HOME/.local/share/tmux/resurrect"
    "$HOME/.config/tmux/resurrect"
)

# Проходим по массиву путей
for p in "${possible_paths[@]}"; do
    if [ -d "$p" ]; then
        # Удаляем и создаем заново, чтобы очистить содержимое
        rm -rf "$p"
        mkdir -p "$p"
        cleaned=1
    fi
done

# Отправляем уведомление в зависимости от результата
if [ "$cleaned" -eq 1 ]; then
    notify-send -h string:x-canonical-private-synchronous:sys-notify "Tmux" "🧹 История сессий (resurrect) очищена"
else
    notify-send -u low -h string:x-canonical-private-synchronous:sys-notify "Tmux" "Файлы сессий не найдены"
fi
