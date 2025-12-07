#!/usr/bin/env bash

# Путь к папке со скриптами действий
REL_DIR="$HOME/.config/hypr/custom/scripts/reload"

# Опции меню
OPT_HYPR="🫀 Hyprland Config"
OPT_WAYBAR="🍄‍🟫 Waybar Config"
OPT_TMUX="💻 Tmux Config"  # <--- Добавили новую опцию

# Генерируем список опций и передаем в walker
# Добавили $OPT_TMUX в список
selected=$(echo -e "$OPT_HYPR\n$OPT_WAYBAR\n$OPT_TMUX" | omarchy-launch-walker -d --placeholder "Reload config...")

# Обработка выбора
case "$selected" in
    "$OPT_HYPR")
        bash "$REL_DIR/hypr.sh"
        ;;
    "$OPT_WAYBAR")
        bash "$REL_DIR/waybar.sh"
        ;;
    "$OPT_TMUX")  # <--- Добавили обработчик
        bash "$REL_DIR/tmux.sh"
        ;;
    *)
        exit 0
        ;;
esac
