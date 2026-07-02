#!/usr/bin/env bash
# Индикатор доступного обновления Omarchy для waybar (return-type: json).
# omarchy-update-available печатает строку вида "Omarchy update available (v3.8.2)"
# только когда есть обновление; при пустом выводе модуль скрыт.
# Разделитель " |" встроен в text по той же схеме, что и indicator-sep.sh.

out=$(omarchy-update-available 2>/dev/null)
[ -z "$out" ] && exit 0

jq -nc --arg tip "$out" \
    '{text: "<span color=\"#cdd6f4\"> |</span> ", tooltip: $tip}'
