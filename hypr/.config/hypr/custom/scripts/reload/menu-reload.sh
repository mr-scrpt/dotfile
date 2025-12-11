#!/usr/bin/env bash

# Путь к папке со скриптами действий
REL_DIR="$HOME/.config/hypr/custom/scripts/reload"

# Опции меню
OPT_HYPR="🫀 Hyprland Config"
OPT_WAYBAR="🍄‍🟫 Waybar Config"
OPT_TMUX="💻 Tmux Config"
OPT_TMUX_CLEAN="🧹 Clean Tmux Sessions"  # <--- Новая опция
OPT_FISH="🐟 Fish Config"
OPT_GHOSTTY="👻 Ghostty Config"

# Генерируем список опций и передаем в walker
# Добавили $OPT_TMUX_CLEAN в список
selected=$(echo -e "$OPT_HYPR\n$OPT_WAYBAR\n$OPT_TMUX\n$OPT_TMUX_CLEAN\n$OPT_FISH\n$OPT_GHOSTTY" | omarchy-launch-walker -d --placeholder "Manage configs...")

# Обработка выбора
case "$selected" in
    "$OPT_HYPR")
        bash "$REL_DIR/hypr.sh"
        ;;
    "$OPT_WAYBAR")
        bash "$REL_DIR/waybar.sh"
        ;;
    "$OPT_TMUX")
        bash "$REL_DIR/tmux.sh"
        ;;
    "$OPT_TMUX_CLEAN")              # <--- Обработка новой опции
        bash "$REL_DIR/tmux_clean.sh"
        ;;
    "$OPT_FISH")
        bash "$REL_DIR/fish.sh"
        ;;
    "$OPT_GHOSTTY")
        bash "$REL_DIR/ghostty.sh"
        ;;
    *)
        exit 0
        ;;
esac
