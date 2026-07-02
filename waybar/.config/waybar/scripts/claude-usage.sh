#!/usr/bin/env bash
# Лимиты Claude Code для waybar: 5-часовое и недельное окно.
# Источник — тот же OAuth-эндпоинт, что питает /usage в самом Claude Code.
# Токен берётся из ~/.claude/.credentials.json и обновляется самим Claude Code.
# Режимы: без аргументов — JSON для waybar; --popup — уведомление с деталями.

CREDS="$HOME/.claude/.credentials.json"
ICON="✳"
CACHE="${XDG_RUNTIME_DIR:-/tmp}/waybar-claude-usage.json"
CACHE_MAX_AGE=1800

MODE=bar
[ "$1" = "--popup" ] && MODE=popup

emit() { # $1=text $2=tooltip $3=class — вывод для waybar
    jq -nc --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

fail() { # $1=короткий текст для бара $2=сообщение
    if [ "$MODE" = popup ]; then
        notify-send -a "Claude Code" -t 8000 "Claude Code — лимиты" "$2"
    else
        emit "$ICON $1" "$2" "offline"
    fi
    exit 0
}

[ -r "$CREDS" ] || fail "?" "Нет файла $CREDS"

TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS")
[ -n "$TOKEN" ] || fail "?" "В credentials нет accessToken"

# У эндпоинта два бакета лимитов по User-Agent: без "claude-code/<версия>"
# запрос попадает в жёсткий бакет (~5 запросов на токен, затем залипший 429),
# с ним — в щедрый, которым пользуется сам Claude Code. Поэтому UA обязателен.
# На случай остаточных 429 последний успешный ответ кэшируется, и при отказе
# показываются данные из кэша (до 30 минут), а не состояние ошибки.
stale_min=""
RESP=""

cache_age() { echo $(($(date +%s) - $(stat -c %Y "$CACHE"))); }

ua() { # User-Agent с версией Claude Code; версия кэшируется на сутки
    local vf="${XDG_RUNTIME_DIR:-/tmp}/claude-code-version" v=""
    if [ ! -r "$vf" ] || [ $(($(date +%s) - $(stat -c %Y "$vf"))) -gt 86400 ]; then
        local bin
        bin=$(command -v claude || echo "$HOME/.local/share/mise/shims/claude")
        "$bin" --version 2>/dev/null | awk '{print $1; exit}' >"$vf"
    fi
    v=$(cat "$vf" 2>/dev/null)
    printf 'claude-code/%s' "${v:-2.1.198}"
}

# Для попапа кэш моложе интервала опроса бара уже актуален — API не дёргаем
if [ "$MODE" = popup ] && [ -r "$CACHE" ] && [ "$(cache_age)" -lt 120 ]; then
    RESP=$(cat "$CACHE")
fi

if [ -z "$RESP" ]; then
    # Без ретраев: на 429 повтор бессмысленен (retry-after всегда 0),
    # деградацию закрывает кэш
    RESP=$(curl -sf --max-time 8 \
        "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $TOKEN" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: $(ua)")
    if [ -n "$RESP" ]; then
        printf '%s' "$RESP" >"$CACHE"
    elif [ -r "$CACHE" ] && [ "$(cache_age)" -lt "$CACHE_MAX_AGE" ]; then
        RESP=$(cat "$CACHE")
        stale_min=$((($(cache_age) + 59) / 60))
    fi
fi

[ -n "$RESP" ] ||
    fail "—" $'API недоступен: rate limit, нет сети или токен истёк\n(токен обновится при следующем запуске Claude Code)'

five=$(jq -r '.five_hour.utilization // 0 | round' <<<"$RESP")
week=$(jq -r '.seven_day.utilization // 0 | round' <<<"$RESP")
five_reset_iso=$(jq -r '.five_hour.resets_at // empty' <<<"$RESP")
week_reset_iso=$(jq -r '.seven_day.resets_at // empty' <<<"$RESP")

rel_time() { # ISO-дата → «2ч 05м» / «3д 21ч» до наступления
    local target diff d h m
    target=$(date -d "$1" +%s 2>/dev/null) || { printf '?'; return; }
    diff=$(((target - $(date +%s)) / 60))
    ((diff < 0)) && diff=0
    d=$((diff / 1440)) h=$(((diff % 1440) / 60)) m=$((diff % 60))
    if ((d > 0)); then
        printf '%dд %dч' "$d" "$h"
    elif ((h > 0)); then
        printf '%dч %02dм' "$h" "$m"
    else
        printf '%dм' "$m"
    fi
}

# Строки сводки: «метка|процент|когда сброс»
rows=()
[ -n "$five_reset_iso" ] &&
    rows+=("5ч сессия|$five|через $(rel_time "$five_reset_iso") ($(date -d "$five_reset_iso" +'%H:%M'))")
[ -n "$week_reset_iso" ] &&
    rows+=("7д все|$week|через $(rel_time "$week_reset_iso") ($(date -d "$week_reset_iso" +'%d.%m %H:%M'))")

# Недельные лимиты по отдельным моделям (weekly_scoped), если сервер их отдаёт
while IFS=$'\t' read -r model pct reset_iso; do
    [ -n "$model" ] &&
        rows+=("7д ${model}|$pct|через $(rel_time "$reset_iso") ($(date -d "$reset_iso" +'%d.%m %H:%M'))")
done < <(jq -r '.limits[]? | select(.kind == "weekly_scoped")
    | [(.scope.model.display_name // "модель"), (.percent // 0 | round | tostring), .resets_at] | @tsv' <<<"$RESP")

# Выравнивание колонок: ${#} считает символы, а не байты, кириллица не ломает
maxlen=0
for r in "${rows[@]}"; do
    l=${r%%|*}
    ((${#l} > maxlen)) && maxlen=${#l}
done

body=""
for r in "${rows[@]}"; do
    IFS='|' read -r l p reset <<<"$r"
    body+=$(printf '%s:%*s %3d%%  сброс %s' "$l" $((maxlen - ${#l})) "" "$p" "$reset")$'\n'
done
body=${body%$'\n'}

warn=""
[ -n "$stale_min" ] && warn="⚠ API недоступен (429) — данные ${stale_min} мин назад"$'\n\n'

if [ "$MODE" = popup ]; then
    notify-send -a "Claude Code" -t 8000 "${ICON} Claude Code — лимиты" "${warn}${body}"
    exit 0
fi

tooltip="Claude Code — лимиты"$'\n\n'"${warn}${body}"

max=$((five > week ? five : week))
class="normal"
[ "$max" -ge 70 ] && class="warning"
[ "$max" -ge 90 ] && class="critical"
[ -n "$stale_min" ] && class="stale"

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
