#!/bin/bash

# --- БЛОК ПРОВЕРОК ---

# 1. Проверяем, установлен ли Tor
if ! command -v tor &> /dev/null; then
    notify-send -u critical -t 8000 "Tor Ошибка ❌" "Пакет 'tor' не установлен!\nВыполните: sudo pacman -S tor"
    exit 1
fi

# 2. Проверяем, запущена ли служба (иначе прокси будет вести в никуда)
if ! systemctl is-active --quiet tor; then
    notify-send -u critical -t 8000 "Tor Ошибка ❌" "Служба Tor остановлена!\nЗапустите: sudo systemctl enable --now tor"
    exit 1
fi

# 3. Проверяем наличие gsettings (нужен для настройки GNOME/Браузеров)
if ! command -v gsettings &> /dev/null; then
    notify-send -u critical -t 8000 "Ошибка" "Не найден 'gsettings'.\nУстановите: sudo pacman -S glib2"
    exit 1
fi

# --- ОСНОВНАЯ ЛОГИКА ---

# Проверяем текущий статус по настройкам GNOME
CURRENT_MODE=$(gsettings get org.gnome.system.proxy mode)

# Адрес прокси
PROXY_HOST="127.0.0.1"
PROXY_PORT="9050"
# ВАЖНО: socks5h означает, что DNS запросы тоже идут через TOR (обход блокировок)
PROXY_URL="socks5h://$PROXY_HOST:$PROXY_PORT"

if [ "$CURRENT_MODE" = "'none'" ]; then
    # --- ВКЛЮЧЕНИЕ ---
    
    # 1. Настройка для GUI приложений (Yandex Browser, Chrome и др.)
    gsettings set org.gnome.system.proxy.socks host "$PROXY_HOST"
    gsettings set org.gnome.system.proxy.socks port $PROXY_PORT
    gsettings set org.gnome.system.proxy mode 'manual'

    # 2. Настройка для Fish Shell (Терминал, git, curl, yay)
    # Используем -Ux для экспорта глобальной переменной во все сессии
    /usr/bin/fish -c "set -Ux all_proxy '$PROXY_URL'"
    /usr/bin/fish -c "set -Ux http_proxy '$PROXY_URL'"
    /usr/bin/fish -c "set -Ux https_proxy '$PROXY_URL'"
    
    # Уведомление
    notify-send -u critical -t 3000 "Tor Proxy" "ВКЛЮЧЕН (Browser + Terminal) 🧅"

else
    # --- ВЫКЛЮЧЕНИЕ ---
    
    # 1. Сброс для GUI
    gsettings set org.gnome.system.proxy mode 'none'

    # 2. Сброс для Fish Shell (Удаляем переменные)
    /usr/bin/fish -c "set -Ue all_proxy"
    /usr/bin/fish -c "set -Ue http_proxy"
    /usr/bin/fish -c "set -Ue https_proxy"
    
    # Уведомление
    notify-send -u low -t 2000 "Tor Proxy" "Выключен ❌"
fi
