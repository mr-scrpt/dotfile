#!/usr/bin/env bash

# Путь к папке со скриптами действий
# Используем $HOME для абсолютного пути
REL_DIR="$HOME/.config/hypr/custom/scripts/reload"

# Опции меню
OPT_HYPR="🫀 Hyprland Config"
OPT_WAYBAR="🍄‍🟫 Waybar Config"

# Генерируем список опций и передаем в walker
# -d включает режим dmenu (чтение из stdin)
selected=$(echo -e "$OPT_HYPR\n$OPT_WAYBAR" | omarchy-launch-walker -d --placeholder "Reload config...")

# Обработка выбора
case "$selected" in
    "$OPT_HYPR")
        bash "$REL_DIR/hypr.sh"
        ;;
    "$OPT_WAYBAR")
        bash "$REL_DIR/waybar.sh"
        ;;
    *)
        exit 0
        ;;
esac
