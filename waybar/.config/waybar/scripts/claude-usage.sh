#!/usr/bin/env bash
# Лимиты Claude Code для waybar: 5-часовое и недельное окно.
# Источник — тот же OAuth-эндпоинт, что питает /usage в самом Claude Code.
# Токен берётся из ~/.claude/.credentials.json, и виджет продлевает его САМ
# (см. refresh_oauth) — локальный Claude Code для этого не нужен. Это важно,
# когда Claude Code гоняется на удалённом сервере: там он обновляет только
# свои серверные креды, а локальные за ночь протухают (access-токен живёт 8ч).
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

# --- Самообновление OAuth-токена --------------------------------------------
# Access-токен живёт 8 часов, а штатно продлевает его только сам Claude Code —
# ночью без него виджет слеп. Поэтому за 5 минут до истечения виджет ходит на
# официальный OAuth-эндпоинт с публичным client_id Claude CLI и пишет новые
# токены обратно в credentials; Claude Code подхватывает их из файла как свои
# (та же схема, что у claudebar из AUR). Refresh-токен одноразовый — ротируется
# при каждом обмене, поэтому окно «прочитал-обновил-записал» сериализуется
# flock'ом: бар и попап могут запуститься одновременно.
TOKEN_URL="https://platform.claude.com/v1/oauth/token"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e" # публичный client_id Claude CLI
REFRESH_BUFFER=${REFRESH_BUFFER:-300}

refresh_oauth() { # обмен refresh-токена на новый access; успех → TOKEN обновлён
    local rt raw code body new_rt exp_in tmp
    rt=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDS")
    [ -n "$rt" ] || return 1
    # User-Agent обязателен: без него эндпоинт токенов, как и /usage, льёт 429
    raw=$(curl -s --max-time 25 -w '\n%{http_code}' -X POST "$TOKEN_URL" \
        -H "Content-Type: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-cli/1.0" \
        --data "$(jq -nc --arg ci "$CLIENT_ID" --arg rt "$rt" \
            '{grant_type: "refresh_token", client_id: $ci, refresh_token: $rt}')")
    code="${raw##*$'\n'}"
    body="${raw%$'\n'"$code"}"
    # 400/401/403 = invalid_grant: refresh-токен отозван (ротация ушла на
    # другой процесс без записи в файл) — лечится только /login, о чём и
    # говорим в статусе вместо общего «нет сети»
    case "$code" in 400 | 401 | 403) REFRESH_DENIED=1 ;; esac
    [ "$code" = 200 ] && jq -e '.access_token' <<<"$body" >/dev/null 2>&1 || return 1
    TOKEN=$(jq -r '.access_token' <<<"$body")
    new_rt=$(jq -r '.refresh_token // empty' <<<"$body")
    exp_in=$(jq -r '.expires_in // 28800 | floor' <<<"$body" 2>/dev/null)
    [[ "$exp_in" =~ ^[0-9]+$ ]] || exp_in=28800
    # mktemp рядом с credentials: права 600 и атомарный mv в той же ФС.
    # Refresh-токен одноразовый, поэтому невозможность записать новый — это
    # потеря авторизации на следующем цикле; но TOKEN в памяти валиден уже
    # сейчас, так что текущий запрос выполняем в любом случае
    tmp=$(mktemp "$CREDS.XXXXXX") || return 0
    jq --arg at "$TOKEN" --arg rt "${new_rt:-$rt}" \
        --argjson ea "$((($(date +%s) + exp_in) * 1000))" \
        '.claudeAiOauth.accessToken = $at
            | .claudeAiOauth.refreshToken = $rt
            | .claudeAiOauth.expiresAt = $ea' \
        "$CREDS" >"$tmp" && mv "$tmp" "$CREDS" || rm -f "$tmp"
    return 0
}

if [ -z "$RESP" ]; then
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-claude-usage.lock"
    if flock -w 30 9; then
        # Перечитать под локом: параллельный инстанс мог уже ротировать токены
        TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS")
        exp_s=$(jq -r '(.claudeAiOauth.expiresAt // 0) / 1000 | floor' "$CREDS")
        # Пока локальный Claude Code запущен, упреждающий refresh делает он —
        # одновременный обмен одного refresh-токена двумя процессами кончается
        # invalid_grant и принудительным /login (грабля CodexBar#1161).
        # Если локальный Claude Code токен так и не продлит (простаивает),
        # сработает 401-ветка ниже: к тому моменту гонки уже не будет
        if [ "$exp_s" -lt "$(($(date +%s) + REFRESH_BUFFER))" ] &&
            ! pgrep -x claude >/dev/null; then
            refresh_oauth || true
            # При неудаче запрос ниже уйдёт со старым токеном: деградацию
            # закрывают кэш и следующий цикл опроса (2 мин)
        fi
    fi
fi

if [ -z "$RESP" ]; then
    fetch_usage() { # RESP непуст только при HTTP 200
        local out
        out=$(curl -s --max-time 8 -w '\n%{http_code}' \
            "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $TOKEN" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: $(ua)")
        HTTP_CODE="${out##*$'\n'}"
        RESP="${out%$'\n'"$HTTP_CODE"}"
        [ "$HTTP_CODE" = 200 ] || RESP=""
    }
    fetch_usage
    # 401 при формально живом access-токене — он отозван (например, токены
    # ротированы с другой машины): принудительный refresh и один повтор.
    # На 429 повтор бессмысленен (retry-after всегда 0), закрывается кэшем
    if [ -z "$RESP" ] && [ "$HTTP_CODE" = 401 ] && refresh_oauth; then
        fetch_usage
    fi
    if [ -n "$RESP" ]; then
        printf '%s' "$RESP" >"$CACHE"
    elif [ -r "$CACHE" ] && [ "$(cache_age)" -lt "$CACHE_MAX_AGE" ]; then
        RESP=$(cat "$CACHE")
        stale_min=$((($(cache_age) + 59) / 60))
    fi
fi

if [ -z "$RESP" ]; then
    if [ -n "$REFRESH_DENIED" ]; then
        fail "!" $'Refresh-токен отозван — выполни /login в Claude Code\n(виджет сам не восстановится, нужна повторная авторизация)'
    fi
    fail "—" $'API недоступен: rate limit или нет сети\n(виджет обновляет токен сам, повтор через 2 мин)'
fi

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
