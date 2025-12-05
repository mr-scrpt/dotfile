#!/usr/bin/env bash

# Команда перезагрузки конфигурации Hyprland
hyprctl reload

# Отправляем уведомление
notify-send -h string:x-canonical-private-synchronous:sys-notify "Hyprland" "Конфигурация перезагружена"
