#!/usr/bin/env bash

# Проверяем, есть ли активные сессии (это более надежный способ проверить, запущен ли сервер)
if tmux list-sessions &>/dev/null; then
  # Перезагружаем конфиг для работающего сервера
  tmux source-file ~/.config/tmux/tmux.conf

  # Отправляем уведомление
  notify-send -h string:x-canonical-private-synchronous:sys-notify "Tmux" "Конфигурация успешно перезагружена"
else
  # Если tmux не запущен, просто уведомляем об этом (опционально)
  notify-send -u low -h string:x-canonical-private-synchronous:sys-notify "Tmux" "Сервер не запущен, конфиг будет применен при старте"
fi
