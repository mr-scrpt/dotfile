#!/usr/bin/env bash
# fzf-пикер каталога -> dev workspace (замена tc + tdev).
# Открывается как popup herdr (plugin pane "picker").
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

# Корни проектов: одна строка на путь в $HERDR_PLUGIN_CONFIG_DIR/roots, иначе дефолт.
roots=()
if [ -f "$PLUGIN_CONFIG_DIR/roots" ]; then
  while IFS= read -r r; do
    r="${r%%#*}"; r="${r/#\~/$HOME}"; r="${r%"${r##*[![:space:]]}"}"
    [ -d "$r" ] && roots+=("$r")
  done <"$PLUGIN_CONFIG_DIR/roots"
fi
[ ${#roots[@]} -gt 0 ] || roots=("$HOME/Work" "$HOME/Projects" "$HOME/Hellkitchen")

collect_dirs() {
  {
    command -v zoxide >/dev/null 2>&1 && zoxide query --list
    fd --type d --max-depth 3 --hidden --exclude .git --exclude node_modules . "${roots[@]}" 2>/dev/null
  } | sed "s|/$||; s|^$HOME|~|" | awk '!seen[$0]++'
}

choice=$(collect_dirs | fzf \
  --prompt='dev space > ' \
  --header='Каталог проекта -> новый dev workspace' \
  --preview 'ls -A --color=always "$(echo {} | sed "s|^~|$HOME|")" 2>/dev/null | head -30' \
  --preview-window=right:40% \
  --height=100% --layout=reverse) || exit 0

dir="${choice/#\~/$HOME}"
[ -d "$dir" ] || { echo "not a directory: $dir" >&2; sleep 2; exit 1; }

# Имя workspace: как в старом tc — basename / parent / своё
last=$(basename "$dir" | tr '.' '_')
parent=$(basename "$(dirname "$dir")" | tr '.' '_')

while :; do
  choice=$(printf '%s\n' \
    "$last  (basename)" \
    "$parent  (parent)" \
    "custom..." \
    | gum choose --header="Имя workspace:" --cursor.foreground=99) || exit 0
  case "$choice" in
    "$last  (basename)") name="$last" ;;
    "$parent  (parent)") name="$parent" ;;
    "custom...") name=$(gum input --prompt="name > " --placeholder="workspace name" | tr '.' '_') ;;
    *) exit 0 ;;
  esac
  [ -n "$name" ] || { echo "empty name"; continue; }
  if workspace_exists "$name"; then
    echo "workspace '$name' already exists — choose another"; continue
  fi
  break
done

create_dev_workspace "$dir" "$name"
