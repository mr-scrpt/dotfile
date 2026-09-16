#!/bin/bash

# --- БЛОК 1: РЕЖИМ ПРОВЕРКИ СТАТУСА (Для Waybar) ---
# Если скрипт запущен с флагом --check, он просто выводит JSON и завершается.
if [[ "$1" == "--check" ]]; then
    STATUS=$(gsettings get org.gnome.system.proxy mode)
    
    if [ "$STATUS" = "'manual'" ]; then
        # ВКЛЮЧЕН (Розовый через CSS класс active)
        echo '{"text": "tor", "tooltip": "Tor Proxy: ACTIVE", "class": "active"}'
    else
        # ВЫКЛЮЧЕН (Серый через CSS класс inactive)
        echo '{"text": "", "tooltip": "Tor Proxy: Disabled", "class": "inactive"}'
    fi
    exit 0
fi

# ==============================================================================
# --- БЛОК 2: РЕЖИМ ПЕРЕКЛЮЧЕНИЯ (Toggle) ---
# Этот код выполняется, если скрипт запущен БЕЗ аргументов (по клику)
# ==============================================================================

# 1. Проверки наличия нужных пакетов
if ! command -v tor &> /dev/null; then
    notify-send -u critical "Tor Error" "Package 'tor' not found!"
    exit 1
fi

if ! systemctl is-active --quiet tor; then
    notify-send -u critical "Tor Error" "Service 'tor' is not running!"
    exit 1
fi

# 2. Настройки
CURRENT_MODE=$(gsettings get org.gnome.system.proxy mode)
PROXY_HOST="127.0.0.1"
PROXY_PORT="9050"
PROXY_URL="socks5h://$PROXY_HOST:$PROXY_PORT" # socks5h для DNS через Tor

if [ "$CURRENT_MODE" = "'none'" ]; then
    # --- ВКЛЮЧЕНИЕ ---
    
    # GUI
    gsettings set org.gnome.system.proxy.socks host "$PROXY_HOST"
    gsettings set org.gnome.system.proxy.socks port $PROXY_PORT
    gsettings set org.gnome.system.proxy mode 'manual'

    # Terminal (Fish)
    /usr/bin/fish -c "set -Ux all_proxy '$PROXY_URL'"
    /usr/bin/fish -c "set -Ux http_proxy '$PROXY_URL'"
    /usr/bin/fish -c "set -Ux https_proxy '$PROXY_URL'"
    
    notify-send -u critical -t 2000 "Tor Proxy" "ENABLED 🧅"

else
    # --- ВЫКЛЮЧЕНИЕ ---
    
    # GUI
    gsettings set org.gnome.system.proxy mode 'none'

    # Terminal (Fish)
    /usr/bin/fish -c "set -Ue all_proxy"
    /usr/bin/fish -c "set -Ue http_proxy"
    /usr/bin/fish -c "set -Ue https_proxy"
    
    notify-send -u low -t 2000 "Tor Proxy" "Disabled ❌"
fi

# 3. Обновляем Waybar (Посылаем сигнал модулю)
# Это заставит waybar перезапустить этот же скрипт, но с флагом --check
pkill -SIGRTMIN+10 waybar
