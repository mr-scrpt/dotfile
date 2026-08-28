#!/usr/bin/env bash
# Лимиты Codex для Waybar через официальный локальный JSON-RPC app-server.
# Скрипт не читает и не обновляет auth.json сам: авторизацией занимается Codex.
# Сеть опрашивается не чаще раза в 5 минут, запросы сериализованы flock'ом,
# после ошибок включается exponential backoff, последний успешный ответ кэшируется.

ICON="✦"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-codex-usage"
CACHE="$CACHE_DIR/last.json"
STATE="$CACHE_DIR/state.json"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/waybar-codex-usage.lock"
POLL_INTERVAL=${CODEX_USAGE_INTERVAL:-300}
MANUAL_MIN_INTERVAL=${CODEX_USAGE_MANUAL_MIN_INTERVAL:-120}
CACHE_MAX_AGE=${CODEX_USAGE_CACHE_MAX_AGE:-86400}
STALE_AFTER=${CODEX_USAGE_STALE_AFTER:-900}

MODE=bar
[ "${1:-}" = "--popup" ] && MODE=popup
[ "${1:-}" = "--refresh" ] && MODE=refresh

umask 077
mkdir -p "$CACHE_DIR"

emit() { # $1=text $2=tooltip $3=class
    jq -nc --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

fail() { # $1=короткий текст $2=сообщение
    if [ "$MODE" = popup ]; then
        notify-send -a "OpenAI Codex" -t 8000 "Codex — лимиты" "$2"
    elif [ "$MODE" = refresh ]; then
        exit 0
    else
        emit "$ICON $1" "$2" "offline"
    fi
    exit 0
}

for dep in codex jq flock; do
    command -v "$dep" >/dev/null 2>&1 || fail "?" "Не найдена команда: $dep"
done

now=$(date +%s)

cache_age() {
    [ -r "$CACHE" ] || { printf '%s' 999999999; return; }
    printf '%s' "$((now - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0)))"
}

state_num() { # $1=поле $2=значение по умолчанию
    local value
    value=$(jq -r --arg key "$1" '.[$key] // empty' "$STATE" 2>/dev/null)
    [[ "$value" =~ ^[0-9]+$ ]] && printf '%s' "$value" || printf '%s' "$2"
}

write_state() { # $1=last_attempt $2=failures $3=next_attempt $4=error
    local tmp
    tmp=$(mktemp "$CACHE_DIR/.state.XXXXXX") || return
    jq -nc --argjson last_attempt "$1" --argjson failures "$2" \
        --argjson next_attempt "$3" --arg error "$4" \
        '{last_attempt: $last_attempt, failures: $failures,
          next_attempt: $next_attempt, last_error: $error}' >"$tmp" &&
        mv "$tmp" "$STATE"
}

fetch_limits() {
    local line response="" error="" initialized=0 deadline server_pid read_fd write_fd

    coproc CODEX_USAGE_SERVER { codex -s read-only -a untrusted app-server 2>/dev/null; }
    server_pid=$CODEX_USAGE_SERVER_PID
    read_fd=${CODEX_USAGE_SERVER[0]}
    write_fd=${CODEX_USAGE_SERVER[1]}

    printf '%s\n' \
        '{"method":"initialize","id":0,"params":{"clientInfo":{"name":"waybar_usage","title":"Waybar Codex Usage","version":"1.0.0"}}}' \
        >&"$write_fd" 2>/dev/null || return 1

    deadline=$((SECONDS + 5))
    while ((SECONDS < deadline)); do
        if IFS= read -r -t 1 -u "$read_fd" line; then
            if jq -e '.id == 0 and .result != null' <<<"$line" >/dev/null 2>&1; then
                initialized=1
                break
            fi
        fi
    done

    if [ "$initialized" -eq 1 ]; then
        printf '%s\n' '{"method":"initialized"}' \
            '{"method":"account/rateLimits/read","id":7}' \
            >&"$write_fd" 2>/dev/null || true

        deadline=$((SECONDS + 10))
        while ((SECONDS < deadline)); do
            if IFS= read -r -t 1 -u "$read_fd" line; then
                if jq -e '.id == 7 and .result.rateLimits != null' <<<"$line" >/dev/null 2>&1; then
                    response=$(jq -c '.result' <<<"$line")
                    break
                elif jq -e '.id == 7 and .error != null' <<<"$line" >/dev/null 2>&1; then
                    error=$(jq -r '.error.message // "app-server error"' <<<"$line")
                    break
                fi
            fi
        done
    else
        error="app-server initialization timeout"
    fi

    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true

    [ -n "$response" ] || return 1
    printf '%s' "$response"
}

last_attempt=$(state_num last_attempt 0)
next_attempt=$(state_num next_attempt 0)
age=$(cache_age)
should_fetch=0

if [ "$now" -ge "$next_attempt" ]; then
    if [ ! -r "$CACHE" ] || [ "$age" -ge "$POLL_INTERVAL" ]; then
        should_fetch=1
    fi
    if [ "$MODE" = refresh ] && [ $((now - last_attempt)) -ge "$MANUAL_MIN_INTERVAL" ]; then
        should_fetch=1
    fi
fi

if [ "$should_fetch" -eq 1 ]; then
    exec 9>"$LOCK"
    if flock -n 9; then
        # Перепроверка под локом: другой Waybar/клик мог уже обновить кэш.
        now=$(date +%s)
        last_attempt=$(state_num last_attempt 0)
        next_attempt=$(state_num next_attempt 0)
        age=$(cache_age)
        if [ "$now" -ge "$next_attempt" ] &&
            { [ ! -r "$CACHE" ] || [ "$age" -ge "$POLL_INTERVAL" ] ||
              { [ "$MODE" = refresh ] && [ $((now - last_attempt)) -ge "$MANUAL_MIN_INTERVAL" ]; }; }; then
            fresh=$(fetch_limits)
            if [ -n "$fresh" ] && jq -e '.rateLimits != null' <<<"$fresh" >/dev/null 2>&1; then
                tmp=$(mktemp "$CACHE_DIR/.last.XXXXXX")
                printf '%s' "$fresh" >"$tmp" && mv "$tmp" "$CACHE"
                write_state "$now" 0 "$((now + POLL_INTERVAL))" ""
            else
                failures=$(state_num failures 0)
                failures=$((failures + 1))
                shift=$((failures - 1))
                ((shift > 3)) && shift=3
                delay=$((POLL_INTERVAL * (1 << shift)))
                ((delay > 3600)) && delay=3600
                write_state "$now" "$failures" "$((now + delay))" \
                    "Codex app-server не вернул лимиты; следующий запрос через $((delay / 60)) мин"
            fi
        fi
    fi
fi

[ "$MODE" = refresh ] && exit 0

[ -r "$CACHE" ] || fail "—" $'Codex пока не вернул данные о лимитах\nПовтор будет выполнен автоматически с безопасной паузой'

now=$(date +%s)
age=$(cache_age)
[ "$age" -le "$CACHE_MAX_AGE" ] || fail "—" "Последние данные Codex старше $((CACHE_MAX_AGE / 3600)) ч"

RESP=$(cat "$CACHE")
jq -e '.rateLimits != null' <<<"$RESP" >/dev/null 2>&1 || fail "!" "Кэш лимитов повреждён"

rel_time() { # Unix timestamp -> «2ч 05м» / «3д 21ч»
    local target=$1 diff d h m
    [[ "$target" =~ ^[0-9]+$ ]] || { printf '?'; return; }
    diff=$(((target - now) / 60))
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

window_label() { # минуты -> короткая русская метка
    local mins=$1
    if ((mins % 1440 == 0)); then
        printf '%dд' "$((mins / 1440))"
    elif ((mins % 60 == 0)); then
        printf '%dч' "$((mins / 60))"
    else
        printf '%dм' "$mins"
    fi
}

reset_text() { # $1=timestamp $2=duration minutes
    local reset=$1 mins=$2 fmt
    ((mins >= 1440)) && fmt='%d.%m %H:%M' || fmt='%H:%M'
    printf 'через %s (%s)' "$(rel_time "$reset")" "$(date -d "@$reset" +"$fmt" 2>/dev/null || echo '?')"
}

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

active_slug=$(sed -nE 's/^[[:space:]]*model[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
    "$HOME/.codex/config.toml" 2>/dev/null | head -n 1)
[ -n "$active_slug" ] || active_slug="gpt-5.6-sol"

case "$active_slug" in
    gpt-5.6-sol) active_display="GPT-5.6 Sol"; model_key="sol" ;;
    gpt-5.6-terra) active_display="GPT-5.6 Terra"; model_key="terra" ;;
    gpt-5.6-luna) active_display="GPT-5.6 Luna"; model_key="luna" ;;
    *)
        active_display="$active_slug"
        model_key=$(tr '[:upper:]' '[:lower:]' <<<"${active_slug##*-}")
        ;;
esac

reasoning=$(sed -nE 's/^[[:space:]]*model_reasoning_effort[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
    "$HOME/.codex/config.toml" 2>/dev/null | head -n 1)

# Если backend когда-нибудь начнёт отдавать отдельный limitName для Sol/Terra,
# используем его. Сегодня обе модели списывают один общий бакет `codex`.
ACTIVE_LIMIT=$(jq -c --arg model "$model_key" '
    . as $root
    | ([($root.rateLimitsByLimitId // {})[]
        | select((.limitName // "" | ascii_downcase | contains($model)))] | first)
      // $root.rateLimits' <<<"$RESP")

five=$(jq -r '
    [.primary, .secondary] | map(select(. != null and .windowDurationMins <= 600))
    | sort_by(.windowDurationMins) | first
    | if . == null then "" else [(.usedPercent // 0 | round), .windowDurationMins, .resetsAt] | @tsv end' \
    <<<"$ACTIVE_LIMIT")
week=$(jq -r '
    [.primary, .secondary] | map(select(. != null and .windowDurationMins >= 1440))
    | sort_by(.windowDurationMins) | last
    | if . == null then "" else [(.usedPercent // 0 | round), .windowDurationMins, .resetsAt] | @tsv end' \
    <<<"$ACTIVE_LIMIT")

[ -n "$five$week" ] || fail "—" "Аккаунт Codex не вернул активные окна лимитов"

missing_bar='<span color="#585b70">▱▱▱▱▱▱▱▱</span>'
max=0
body=""
text=""

# На панели всегда два слота, как в исходном Claude-виджете. Для отсутствующего
# окна остаётся только пустая шкала: без выдуманного процента и без текста.
if [ -n "$five" ]; then
    IFS=$'\t' read -r five_pct five_mins five_reset <<<"$five"
    ((five_pct > max)) && max=$five_pct
    text+="<span color='#7f849c'>󰅐</span> $(bar "$five_pct" "#89dceb") ${five_pct}% "
    body+=$(printf '5ч окно:  %3d%%  сброс %s' "$five_pct" "$(reset_text "$five_reset" "$five_mins")")$'\n'
else
    text+="<span color='#7f849c'>󰅐</span> ${missing_bar} "
    body+=$'5ч окно:    —    не предоставлено сервером для этого аккаунта\n'
fi

if [ -n "$week" ]; then
    IFS=$'\t' read -r week_pct week_mins week_reset <<<"$week"
    ((week_pct > max)) && max=$week_pct
    text+="<span color='#7f849c'>󰃭</span> $(bar "$week_pct" "#cba6f7") ${week_pct}%"
    body+=$(printf '7д окно:  %3d%%  сброс %s' "$week_pct" "$(reset_text "$week_reset" "$week_mins")")
else
    text+="<span color='#7f849c'>󰃭</span> ${missing_bar}"
    body+=$'7д окно:    —    не предоставлено сервером для этого аккаунта'
fi

# Sol и Terra могут получить отдельные серверные бакеты в будущем. Пока их нет,
# явно объясняем общий пул и разный темп расходования вместо показа Spark.
distinct_models=$(jq -r '
    [(.rateLimitsByLimitId // {})[]
     | select((.limitName // "") | test("GPT-5\\.6[- ](Sol|Terra)"; "i"))]
    | length' <<<"$RESP")

model_info=$'\n\nМодели и расход общего пула:'
if ((distinct_models > 0)); then
    while IFS=$'\t' read -r name pct mins reset; do
        [ -n "$name" ] || continue
        model_info+=$'\n'"• $name · $(window_label "$mins"): ${pct}% · $(reset_text "$reset" "$mins")"
    done < <(jq -r '
        (.rateLimitsByLimitId // {})[]
        | select((.limitName // "") | test("GPT-5\\.6[- ](Sol|Terra)"; "i"))
        | . as $limit | [$limit.primary, $limit.secondary][] | select(. != null)
        | [$limit.limitName, (.usedPercent // 0 | round), .windowDurationMins, .resetsAt]
        | @tsv' <<<"$RESP")
else
    if [ "$active_slug" = "gpt-5.6-sol" ]; then
        model_info+=$'\n'"• GPT-5.6 Sol — ×2 · активна"
        model_info+=$'\n'"• GPT-5.6 Terra — ×1"
    elif [ "$active_slug" = "gpt-5.6-terra" ]; then
        model_info+=$'\n'"• GPT-5.6 Sol — ×2"
        model_info+=$'\n'"• GPT-5.6 Terra — ×1 · активна"
    else
        model_info+=$'\n'"• GPT-5.6 Sol — ×2"
        model_info+=$'\n'"• GPT-5.6 Terra — ×1"
    fi
fi

plan=$(jq -r '.rateLimits.planType // empty' <<<"$RESP")
case "$plan" in prolite) plan="Pro Lite" ;; esac
credits=$(jq -r '.rateLimitResetCredits.availableCount // 0' <<<"$RESP")
extra=""
[ -n "$plan" ] && extra+=$'\n'"План: $plan"
((credits > 0)) && extra+=$'\n'"Доступно полных сбросов: $credits"

last_error=$(jq -r '.last_error // empty' "$STATE" 2>/dev/null)
stale=""
if [ "$age" -ge "$STALE_AFTER" ] || [ -n "$last_error" ]; then
    stale="⚠ Данные $(((age + 59) / 60)) мин назад"
    [ -n "$last_error" ] && stale+=$'\n'"$last_error"
    stale+=$'\n\n'
fi

model_header="$active_display"
[ -n "$reasoning" ] && model_header+=" · $reasoning"
tooltip="Codex · ${model_header}"$'\n\n'"${stale}${body}${model_info}${extra}"

if [ "$MODE" = popup ]; then
    notify-send -a "OpenAI Codex" -t 8000 "$ICON Codex · ${active_display}" \
        "${stale}${body}${model_info}${extra}"
    exit 0
fi

class="normal"
[ "$max" -ge 70 ] && class="warning"
[ "$max" -ge 90 ] && class="critical"
[ -n "$stale" ] && class="stale"

emit "$text" "$tooltip" "$class"
