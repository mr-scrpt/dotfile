#!/usr/bin/env bash
# Убиваем текущий процесс
killall -q waybar
# Ждем, пока процесс исчезнет
while pgrep -x waybar >/dev/null; do sleep 0.1; done
# Запускаем заново
uwsm-app -- waybar &
notify-send -h string:x-canonical-private-synchronous:sys-notify "Waybar" "Перезагружен успешно"
