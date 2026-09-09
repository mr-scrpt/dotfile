#!/usr/bin/env bash
# Общий движок devspace: создание workspace с набором вкладок.
# Аналог session-launcher из старого tmux-сетапа (tdev/tconf).
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"

hj() { "$HERDR" "$@"; } # herdr отвечает JSON'ом в stdout

workspace_exists() {
  local label="$1"
  hj workspace list | jq -e --arg l "$label" \
    '.result.workspaces[] | select(.label == $l)' >/dev/null 2>&1
}

# create_workspace <label> <cwd> -> печатает "ws_id tab_id pane_id"
create_workspace() {
  local label="$1" cwd="$2" out
  out=$(hj workspace create --cwd "$cwd" --label "$label" --focus)
  echo "$out" | jq -r '[.result.workspace.workspace_id, .result.tab.tab_id, .result.root_pane.pane_id] | join(" ")'
}

# add_tab <ws_id> <label> <cwd> [cmd...] -> печатает pane_id новой вкладки
add_tab() {
  local ws_id="$1" label="$2" cwd="$3" out pane_id
  shift 3
  out=$(hj tab create --workspace "$ws_id" --cwd "$cwd" --label "$label" --no-focus)
  pane_id=$(echo "$out" | jq -r '.result.root_pane.pane_id')
  if [ "$#" -gt 0 ] && command -v "$1" >/dev/null 2>&1; then
    hj pane run "$pane_id" "$@" >/dev/null
  fi
  echo "$pane_id"
}

# Аналог tdev: dev-workspace вокруг каталога проекта.
# Вкладки: editor(nvim) / server / infra / terminal / docker(lazydocker) / files
create_dev_workspace() {
  local dir="$1" name ws_id tab1 pane1
  name=$(basename "$dir")

  if workspace_exists "$name"; then
    echo "workspace '$name' already exists" >&2
    return 0
  fi

  read -r ws_id tab1 pane1 <<<"$(create_workspace "$name" "$dir")"

  hj tab rename "$tab1" " editor" >/dev/null
  command -v nvim >/dev/null 2>&1 && hj pane run "$pane1" nvim >/dev/null

  add_tab "$ws_id" " server"   "$dir" >/dev/null
  add_tab "$ws_id" " infra"    "$dir" >/dev/null
  add_tab "$ws_id" " terminal" "$dir" >/dev/null
  add_tab "$ws_id" " docker"   "$dir" lazydocker >/dev/null
  add_tab "$ws_id" " files"    "$dir" yazi >/dev/null

  hj tab focus "$tab1" >/dev/null
  echo "created dev workspace '$name' ($ws_id) at $dir"
}
