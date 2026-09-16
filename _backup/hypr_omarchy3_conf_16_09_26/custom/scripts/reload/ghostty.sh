#!/usr/bin/env bash

# Ghostty has a reload_config action bound to Ctrl+Shift+, by default
# Unfortunately, there's no CLI command yet to trigger reload via IPC
# (feature discussion: https://github.com/ghostty-org/ghostty/issues/...)

# Find all Ghostty windows using hyprctl
ghostty_count=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address' | wc -l)

if [ "$ghostty_count" -eq 0 ]; then
    notify-send -h string:x-canonical-private-synchronous:sys-notify "Ghostty" "No running Ghostty windows found."
    exit 0
fi

# Copy helpful message to clipboard (no terminal command exists for Ghostty reload)
echo "# Ghostty reload: Press Ctrl+Shift+, (comma) in each Ghostty window" | wl-copy

# Show helpful notification
notify-send -h string:x-canonical-private-synchronous:sys-notify "Ghostty" "Reload instruction copied to clipboard 📋\n($ghostty_count window(s) running)\nPress Ctrl+Shift+, (comma) in each window 👻"


