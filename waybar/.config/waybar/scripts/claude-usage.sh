#!/usr/bin/env bash
# Лимиты Claude Code для waybar: 5-часовое и недельное окно.
# Источник — тот же OAuth-эндпоинт, что питает /usage в самом Claude Code.
# Токен берётся из ~/.claude/.credentials.json и обновляется самим Claude Code.

CREDS="$HOME/.claude/.credentials.json"
ICON="✳"

emit() { # $1=text $2=tooltip $3=class
    jq -nc --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
    exit 0
}

[ -r "$CREDS" ] || emit "$ICON ?" "Нет файла $CREDS" "offline"

TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS")
[ -n "$TOKEN" ] || emit "$ICON ?" "В credentials нет accessToken" "offline"

# Эндпоинт рейт-лимитится (429), причём лимит общий с самим Claude Code.
# Поэтому последний успешный ответ кэшируется, и при временном отказе
# показываются данные из кэша (до 30 минут), а не состояние ошибки.
CACHE="${XDG_RUNTIME_DIR:-/tmp}/waybar-claude-usage.json"
CACHE_MAX_AGE=1800

stale_min=""
RESP=$(curl -sf --max-time 8 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20")

if [ -n "$RESP" ]; then
    printf '%s' "$RESP" >"$CACHE"
elif [ -r "$CACHE" ]; then
    age=$(($(date +%s) - $(stat -c %Y "$CACHE")))
    if [ "$age" -lt "$CACHE_MAX_AGE" ]; then
        RESP=$(cat "$CACHE")
        stale_min=$(((age + 59) / 60))
    fi
fi

[ -n "$RESP" ] ||
    emit "$ICON —" $'API недоступен: rate limit, нет сети или токен истёк\n(токен обновится при следующем запуске Claude Code)' "offline"

five=$(jq -r '.five_hour.utilization // 0 | round' <<<"$RESP")
week=$(jq -r '.seven_day.utilization // 0 | round' <<<"$RESP")
five_reset_iso=$(jq -r '.five_hour.resets_at // empty' <<<"$RESP")
week_reset_iso=$(jq -r '.seven_day.resets_at // empty' <<<"$RESP")

five_reset=""
week_reset=""
[ -n "$five_reset_iso" ] && five_reset=$(date -d "$five_reset_iso" +'%H:%M')
[ -n "$week_reset_iso" ] && week_reset=$(date -d "$week_reset_iso" +'%d.%m %H:%M')

tooltip="Claude Code — лимиты"
tooltip+=$'\n'"5-часовое окно: ${five}%"
[ -n "$five_reset" ] && tooltip+=" (сброс в ${five_reset})"
tooltip+=$'\n'"Неделя, все модели: ${week}%"
[ -n "$week_reset" ] && tooltip+=" (сброс ${week_reset})"

# Недельные лимиты по отдельным моделям (weekly_scoped), если сервер их отдаёт
while IFS=$'\t' read -r model pct; do
    [ -n "$model" ] && tooltip+=$'\n'"Неделя, ${model}: ${pct}%"
done < <(jq -r '.limits[]? | select(.kind == "weekly_scoped")
    | [(.scope.model.display_name // "модель"), (.percent // 0 | round | tostring)] | @tsv' <<<"$RESP")

max=$((five > week ? five : week))
class="normal"
[ "$max" -ge 70 ] && class="warning"
[ "$max" -ge 90 ] && class="critical"

if [ -n "$stale_min" ]; then
    class="stale"
    tooltip+=$'\n'"⚠ Данные ${stale_min} мин назад — API временно недоступен (429)"
fi

# Сегментный прогресс-бар (8 сегментов) с pango-цветами, палитра Catppuccin Mocha:
# базовый цвет свой на каждое окно, от 70% — жёлтый, от 90% — красный
bar() { # $1=процент $2=базовый цвет
    local pct=$1 color=$2 filled i f="" e=""
    filled=$(((pct * 8 + 50) / 100))
    ((filled > 8)) && filled=8
    ((pct >= 70)) && color="#f9e2af"
    ((pct >= 90)) && color="#f38ba8"
    for ((i = 0; i < filled; i++)); do f+="▰"; done
    for ((i = filled; i < 8; i++)); do e+="▱"; done
    printf '<span color="%s">%s</span><span color="#585b70">%s</span>' "$color" "$f" "$e"
}

text="<span color='#7f849c'>󰅐</span> $(bar "$five" "#89dceb") ${five}%"
text+=" <span color='#7f849c'>󰃭</span> $(bar "$week" "#cba6f7") ${week}%"

emit "$text" "$tooltip" "$class"
