#!/bin/bash

# Waits for Hyprland IPC socket
while [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; do
    sleep 1
    # Try to find it if not in env
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 ${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/ | head -n 1)
done

SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

apply_color() {
    local LAYOUT="$1"
    local COLORS_FILE="$HOME/.local/state/omarchy/current/theme/colors.toml"
    
    # Extract colors from the current theme and remove the #
    local YELLOW=$(grep -m 1 '^yellow = ' "$COLORS_FILE" | cut -d'"' -f2 | sed 's/#//')
    local MAGENTA=$(grep -m 1 '^magenta = ' "$COLORS_FILE" | cut -d'"' -f2 | sed 's/#//')
    local DEFAULT=$(grep -m 1 '^accent = ' "$COLORS_FILE" | cut -d'"' -f2 | sed 's/#//')

    # Fallbacks
    YELLOW=${YELLOW:-e0af68}
    MAGENTA=${MAGENTA:-bb9af7}
    DEFAULT=${DEFAULT:-7aa2f7}

    if [[ "$LAYOUT" == *"Russian"* || "$LAYOUT" == *"ru"* || "$LAYOUT" == *"Русская"* ]]; then
      hyprctl eval "hl.config({ general = { ['col.active_border'] = 'rgb(${YELLOW})' } })"
    elif [[ "$LAYOUT" == *"English"* || "$LAYOUT" == *"us"* ]]; then
      hyprctl eval "hl.config({ general = { ['col.active_border'] = 'rgb(${MAGENTA})' } })"
    else
      hyprctl eval "hl.config({ general = { ['col.active_border'] = 'rgb(${DEFAULT})' } })"
    fi
}

# Apply for current layout
CURRENT_LAYOUT=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -n 1)
if [ -n "$CURRENT_LAYOUT" ]; then
    apply_color "$CURRENT_LAYOUT"
fi

handle() {
  local EVENT="$1"
  if [[ "$EVENT" == activelayout* ]]; then
    local LAYOUT="${EVENT#*>>}"
    apply_color "$LAYOUT"
  fi
}

socat - UNIX-CONNECT:"$SOCKET" | while read -r line; do handle "$line"; done
