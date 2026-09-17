#!/usr/bin/env bash
# Синхронизация workspace'ов dotfile и config с файловой системой.
# Идемпотентен; вызывается: на старте сервера, по событию workspace.focused,
# по хоткею (action "sync") и вручную: bash sync.sh [dotfile|config|all]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

target="${1:-all}"

# Событие workspace.focused: синхронизируем только тот workspace, куда пришли.
if [ "${HERDR_PLUGIN_EVENT:-}" = "workspace.focused" ] && [ -n "${HERDR_PLUGIN_EVENT_JSON:-}" ]; then
  ws_id=$(printf '%s' "$HERDR_PLUGIN_EVENT_JSON" | jq -r '.. | .workspace_id? // empty' | head -n1)
  label=$(hj workspace list | jq -r --arg id "$ws_id" \
    '.result.workspaces[] | select(.workspace_id == $id) | .label')
  case "$label" in
    dotfile) target=dotfile ;;
    config)  target=config ;;
    *) exit 0 ;;
  esac
fi

case "$target" in
  dotfile) sync_dotfile ;;
  config)  sync_config ;;
  all)     sync_dotfile; sync_config ;;
  *) echo "usage: sync.sh [dotfile|config|all]" >&2; exit 2 ;;
esac

# Тост показываем только при явном вызове (хоткей/CLI); по событию focus и на старте — молча.
[ "${HERDR_PLUGIN_EVENT:-}" = "" ] && notify_sync
exit 0
