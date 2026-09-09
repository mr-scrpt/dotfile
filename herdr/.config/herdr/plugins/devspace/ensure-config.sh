#!/usr/bin/env bash
# Замена tconf: workspace "config" со вкладками по конфигам.
# Запускается автоматически startup-хуком herdr; идемпотентен.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

WS_LABEL="config"

# name:path — вкладка создаётся только если каталог существует.
# Если склонируешь дотфайлы (например в ~/Hellkitchen/dotfile) — поменяй пути здесь.
TABS=(
  " nvim:$HOME/.config/nvim"
  " hypr:$HOME/.config/hypr"
  " herdr:$HOME/.config/herdr"
  " ghostty:$HOME/.config/ghostty"
  " kitty:$HOME/.config/kitty"
  " fish:$HOME/.config/fish"
  " bin:$HOME/.local/bin"
  " omarchy:$HOME/.config/omarchy"
)

if workspace_exists "$WS_LABEL"; then
  echo "config workspace already exists"
  exit 0
fi

first=1
ws_id=""
for entry in "${TABS[@]}"; do
  name="${entry%%:*}"
  path="${entry#*:}"
  [ -d "$path" ] || continue

  if [ "$first" = 1 ]; then
    read -r ws_id tab1 _ <<<"$(create_workspace "$WS_LABEL" "$path")"
    hj tab rename "$tab1" "$name" >/dev/null
    first=0
  else
    add_tab "$ws_id" "$name" "$path" >/dev/null
  fi
done

if [ -n "$ws_id" ]; then
  echo "created config workspace ($ws_id)"
else
  echo "no config directories found, nothing created" >&2
fi
