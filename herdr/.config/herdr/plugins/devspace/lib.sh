#!/usr/bin/env bash
# devspace — общий движок. Аналог session-launcher из старого tmux-сетапа (tdev/tconf).
# Все вызовы herdr идут через HERDR_BIN_PATH (его инжектит herdr в плагин-команды).
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
DOTFILE_DIR="${DOTFILE_DIR:-$HOME/Hellkitchen/dotfile}"
CONFIG_DIR="$HOME/.config"

# Каталог пользовательского конфига плагина (ignore-список и т.п.).
# herdr задаёт HERDR_PLUGIN_CONFIG_DIR; для ручного запуска — fallback.
PLUGIN_CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/mrscrpt.devspace}"

hj() { "$HERDR" "$@"; } # herdr отвечает JSON'ом в stdout

log() { printf '[devspace] %s\n' "$*" >&2; }

# ---------------------------------------------------------------- herdr API

# workspace_id <label> -> печатает id или пусто
workspace_id() {
  hj workspace list | jq -r --arg l "$1" \
    '.result.workspaces[] | select(.label == $l) | .workspace_id' | head -n1
}

workspace_exists() { [ -n "$(workspace_id "$1")" ]; }

# create_workspace <label> <cwd> [--focus|--no-focus] -> "ws_id tab_id pane_id"
create_workspace() {
  local label="$1" cwd="$2" focus="${3:---no-focus}"
  hj workspace create --cwd "$cwd" --label "$label" "$focus" \
    | jq -r '[.result.workspace.workspace_id, .result.tab.tab_id, .result.root_pane.pane_id] | join(" ")'
}

# tab_labels <ws_id> -> по метке на строку
tab_labels() {
  hj tab list --workspace "$1" | jq -r '.result.tabs[].label'
}

# add_tab <ws_id> <label> <cwd> [cmd...] -> pane_id
# Команда запускается только если бинарь есть в PATH.
add_tab() {
  local ws_id="$1" label="$2" cwd="$3" pane_id
  shift 3
  pane_id=$(hj tab create --workspace "$ws_id" --cwd "$cwd" --label "$label" --no-focus \
    | jq -r '.result.root_pane.pane_id')
  if [ "$#" -gt 0 ] && command -v "$1" >/dev/null 2>&1; then
    hj pane run "$pane_id" "$@" >/dev/null
  fi
  echo "$pane_id"
}

# ---------------------------------------------------------------- stow

# stow_target <pkg_dir> -> целевой каталог внутри пакета.
# Пакет зеркалит $HOME (или /), т.е. сверху — цепочка "транзитных" каталогов
# с единственным потомком. Спускаемся, пока каталог содержит ровно один
# подкаталог и ничего больше; останавливаемся на каталоге с именем пакета.
#   nvim/.config/nvim/{init.lua,lua}  -> .config/nvim
#   ssh/.ssh/config                   -> .ssh
#   system/etc/{chromium,systemd}     -> etc   (ветвление)
stow_target() {
  local d="$1" name entries e
  name=$(basename "$1")
  while :; do
    [ "$d" != "$1" ] && [ "$(basename "$d")" = "$name" ] && break
    entries=()
    for e in "$d"/* "$d"/.[!.]* "$d"/..?*; do
      [ -e "$e" ] || continue
      [ "$(basename "$e")" = ".git" ] && continue
      entries+=("$e")
    done
    [ ${#entries[@]} -eq 1 ] && [ -d "${entries[0]}" ] || break
    d="${entries[0]}"
  done
  echo "$d"
}

# ---------------------------------------------------------------- источники вкладок

# Печатает "label<TAB>dir" на строку.
dotfile_tabs() {
  [ -d "$DOTFILE_DIR" ] || return 0
  printf ' repo\t%s\n' "$DOTFILE_DIR"
  local pkg
  for pkg in "$DOTFILE_DIR"/*/; do
    pkg="${pkg%/}"
    [ -d "$pkg" ] || continue
    case "$(basename "$pkg")" in .*|_*) continue ;; esac
    printf '%s\t%s\n' "$(basename "$pkg")" "$(stow_target "$pkg")"
  done
}

# ignore-список: по glob-паттерну на строку, # — комментарий
config_ignored() {
  local name="$1" pat
  [ -f "$PLUGIN_CONFIG_DIR/config.ignore" ] || return 1
  while IFS= read -r pat; do
    pat="${pat%%#*}"; pat="${pat// /}"
    [ -n "$pat" ] || continue
    # shellcheck disable=SC2254
    case "$name" in $pat) return 0 ;; esac
  done <"$PLUGIN_CONFIG_DIR/config.ignore"
  return 1
}

config_tabs() {
  local d name
  for d in "$CONFIG_DIR"/*/; do
    d="${d%/}"
    name=$(basename "$d")
    [ -d "$d" ] || continue
    [ -L "$d" ] && continue            # симлинк из stow -> уже в workspace dotfile
    config_ignored "$name" && continue
    printf '%s\t%s\n' "$name" "$d"
  done
  # каталоги вне ~/.config, но тоже "конфиг"
  [ -d "$HOME/.local/bin" ] && printf 'bin\t%s\n' "$HOME/.local/bin"
  [ -d "$HOME/.hermes" ] && printf 'hermes\t%s\n' "$HOME/.hermes"
  return 0
}

# ---------------------------------------------------------------- sync

# sync_workspace <label> <tabs-fn> [first-tab-cmd...]
# Идемпотентно: создаёт workspace, если нет; добавляет вкладки, которых нет.
# Закрытые пользователем вкладки не возвращает — только НОВЫЕ каталоги.
sync_workspace() {
  local label="$1" tabs_fn="$2"; shift 2
  local ws_id existing added=0 tab_label dir first_pane

  ws_id=$(workspace_id "$label")
  existing=""
  [ -n "$ws_id" ] && existing=$(tab_labels "$ws_id")

  while IFS=$'\t' read -r tab_label dir; do
    [ -n "$tab_label" ] || continue
    if [ -z "$ws_id" ]; then
      read -r ws_id _ first_pane <<<"$(create_workspace "$label" "$dir" --no-focus)"
      hj tab rename "$ws_id:t1" "$tab_label" >/dev/null 2>&1 || true
      if [ "$#" -gt 0 ] && command -v "$1" >/dev/null 2>&1; then
        hj pane run "$first_pane" "$@" >/dev/null
      fi
      existing="$tab_label"; added=$((added + 1)); continue
    fi
    if ! printf '%s\n' "$existing" | grep -qxF "$tab_label"; then
      add_tab "$ws_id" "$tab_label" "$dir" >/dev/null
      existing="$existing"$'\n'"$tab_label"; added=$((added + 1))
    fi
  done < <("$tabs_fn")

  log "$label: $added new tab(s)"
  SYNC_SUMMARY="${SYNC_SUMMARY:+$SYNC_SUMMARY, }$label +$added"
}

# Тост в herdr с итогом синка (только если было что-то вызвано явно, не по событию)
notify_sync() {
  [ -n "${SYNC_SUMMARY:-}" ] || return 0
  hj notification show "devspace sync" --body "$SYNC_SUMMARY" >/dev/null 2>&1 || true
}

sync_dotfile() { sync_workspace "dotfile" dotfile_tabs lazygit; }
sync_config()  { sync_workspace "config"  config_tabs; }

# ---------------------------------------------------------------- dev workspace (tdev)

# create_dev_workspace <dir> [name]
create_dev_workspace() {
  local dir="$1" name="${2:-$(basename "$1")}" ws_id tab1 pane1
  if workspace_exists "$name"; then
    log "workspace '$name' already exists"; return 1
  fi
  read -r ws_id tab1 pane1 <<<"$(create_workspace "$name" "$dir" --focus)"
  hj tab rename "$tab1" " editor" >/dev/null
  command -v nvim >/dev/null 2>&1 && hj pane run "$pane1" nvim >/dev/null

  add_tab "$ws_id" " server"   "$dir" >/dev/null
  add_tab "$ws_id" " infra"    "$dir" >/dev/null
  add_tab "$ws_id" " terminal" "$dir" >/dev/null
  add_tab "$ws_id" " docker"   "$dir" lazydocker >/dev/null
  add_tab "$ws_id" " files"    "$dir" yazi >/dev/null

  hj tab focus "$tab1" >/dev/null
  log "created dev workspace '$name' at $dir"
}
