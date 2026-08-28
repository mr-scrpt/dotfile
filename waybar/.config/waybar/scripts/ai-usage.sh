#!/usr/bin/env bash
# Переключатель активного AI usage-виджета. Claude-модуль и его скрипт сохранены.

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
STATE="$STATE_DIR/ai-usage-provider"
BASE="$HOME/.config/waybar/scripts"
SIGNAL=9

provider=$(cat "$STATE" 2>/dev/null)
case "$provider" in claude | codex) ;; *) provider=codex ;; esac

save_provider() {
    local next=$1 tmp
    mkdir -p "$STATE_DIR"
    tmp=$(mktemp "$STATE_DIR/.ai-usage-provider.XXXXXX") || exit 1
    printf '%s\n' "$next" >"$tmp" && mv "$tmp" "$STATE"
}

signal_waybar() {
    pkill -RTMIN+$SIGNAL waybar 2>/dev/null || true
}

case "${1:-}" in
    --toggle)
        [ "$provider" = codex ] && provider=claude || provider=codex
        save_provider "$provider"
        signal_waybar
        [ "$provider" = codex ] && name="Codex" || name="Claude Code"
        notify-send -a "Waybar" -t 2500 "AI-лимиты" "Активный виджет: $name"
        exit 0
        ;;
    --set)
        case "${2:-}" in
            claude | codex) save_provider "$2"; signal_waybar ;;
            *) printf 'usage: %s --set {codex|claude}\n' "$0" >&2; exit 2 ;;
        esac
        exit 0
        ;;
    --refresh)
        if [ "$provider" = codex ]; then
            "$BASE/codex-usage.sh" --refresh >/dev/null 2>&1
        fi
        signal_waybar
        exit 0
        ;;
    --popup)
        exec "$BASE/${provider}-usage.sh" --popup
        ;;
esac

json=$("$BASE/${provider}-usage.sh")
hint=$'\n\nСредний клик: Codex ↔ Claude\nПравый клик: безопасное обновление'
if jq -e . >/dev/null 2>&1 <<<"$json"; then
    jq -c --arg hint "$hint" '.tooltip = ((.tooltip // "") + $hint)' <<<"$json"
else
    printf '%s\n' "$json"
fi
