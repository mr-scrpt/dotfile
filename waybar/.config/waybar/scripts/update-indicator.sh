#!/usr/bin/env bash
# Индикатор доступного обновления Omarchy для waybar (return-type: json).
# omarchy-update-available печатает строку вида "Omarchy update available (v3.8.2)"
# только когда есть обновление; при пустом выводе модуль скрыт.
# Разделитель " |" встроен в text по той же схеме, что и indicator-sep.sh.

out=$(omarchy-update-available 2>/dev/null)
[ -z "$out" ] && exit 0

# Иконка задана escape-последовательностью \uf021 (nf-fa-refresh): живой глиф
# в файле легко потерять при редактировании — так индикатор уже ломался.
# Хвостовой пробел обязателен: глиф рисуется шире своей метрической ширины,
# и без запаса GTK обрезает его правый край.
jq -nc --arg tip "$out" \
    '{text: "<span color=\"#cdd6f4\"> |</span> \uf021 ", tooltip: $tip}'
