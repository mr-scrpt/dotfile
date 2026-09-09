#!/usr/bin/env bash
# fzf-пикер каталога -> создание dev-workspace (замена ручного tdev).
# Открывается как popup-пейн herdr (plugin pane "picker").
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

# Источники каталогов:
#  1) zoxide — где реально бываешь (по рангу)
#  2) fd — ~/Work и ~/Projects, глубина 3
ROOTS=("$HOME/Work" "$HOME/Projects")

collect_dirs() {
  {
    command -v zoxide >/dev/null 2>&1 && zoxide query --list
    if command -v fd >/dev/null 2>&1; then
      fd --type d --max-depth 3 --hidden --exclude .git --exclude node_modules . "${ROOTS[@]}" 2>/dev/null
    else
      find "${ROOTS[@]}" -maxdepth 3 -type d ! -path '*/.git*' ! -path '*node_modules*' 2>/dev/null
    fi
  } | sed "s|^$HOME|~|" | awk '!seen[$0]++'
}

choice=$(collect_dirs | fzf \
  --prompt='dev space > ' \
  --header='Выбери каталог проекта — будет создан dev workspace' \
  --preview 'ls -A --color=always "$(echo {} | sed "s|^~|$HOME|")" 2>/dev/null | head -30' \
  --preview-window=right:40% \
  --height=100% --layout=reverse) || exit 0

dir=$(echo "$choice" | sed "s|^~|$HOME|")
[ -d "$dir" ] || { echo "not a directory: $dir" >&2; sleep 2; exit 1; }

create_dev_workspace "$dir"
