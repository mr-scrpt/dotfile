#!/usr/bin/env bash

# Путь к папке со скриптами действий
REL_DIR="$HOME/.config/hypr/custom/scripts/reload"
TOG_DIR="$HOME/.config/hypr/custom/scripts/toggler/"

# --- ОПРЕДЕЛЯЕМ СТАТУС TOR ---
# Проверяем, включен ли сейчас прокси
if [ "$(gsettings get org.gnome.system.proxy mode)" = "'manual'" ]; then
    # ВКЛЮЧЕН: Используем Зеленый или Фиолетовый круг для привлечения внимания
    # 🟣 - отлично сочетается с темой Catppuccin
    # 🟢 - классический "Включено"
    OPT_TOR="🟢 Tor Proxy: [ON]  -> Disable"
else
    # ВЫКЛЮЧЕН: Серый или пустой круг
    OPT_TOR="🟣 Tor Proxy: [OFF] -> Enable"
fi

# Опции меню
OPT_HYPR="🫀 Hyprland Config"
OPT_WAYBAR="🍄‍🟫 Waybar Config"
OPT_TMUX="💻 Tmux Config"
OPT_TMUX_CLEAN="🧹 Clean Tmux Sessions"
OPT_FISH="🐟 Fish Config"
OPT_GHOSTTY="👻 Ghostty Config"

# Генерируем список опций и передаем в walker
# Добавил $OPT_TOR в список
selected=$(echo -e "$OPT_TOR\n$OPT_HYPR\n$OPT_WAYBAR\n$OPT_TMUX\n$OPT_TMUX_CLEAN\n$OPT_FISH\n$OPT_GHOSTTY" | omarchy-launch-walker -d --placeholder "Manage configs...")

# Обработка выбора
case "$selected" in
    "$OPT_TOR")
        # Переменная OPT_TOR содержит теги span, поэтому case сработает корректно,
        # так как walker вернет строку в том же виде, в каком получил.
        bash "$TOG_DIR/tor-toggler.sh"
        ;;
    "$OPT_HYPR")
        bash "$REL_DIR/hypr.sh"
        ;;
    "$OPT_WAYBAR")
        bash "$REL_DIR/waybar.sh"
        ;;
    "$OPT_TMUX")
        bash "$REL_DIR/tmux.sh"
        ;;
    "$OPT_TMUX_CLEAN")
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
