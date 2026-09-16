#!/usr/bin/env bash

# SAFE VERSION: Only copies reload command to clipboard
# This avoids the risk of terminating Fish processes with USR1 signal
# if the reload handler function is not installed.

# Find all running Fish shell processes
fish_pids=$(pgrep -x fish)

if [ -z "$fish_pids" ]; then
    notify-send -h string:x-canonical-private-synchronous:sys-notify "Fish Shell" "No running Fish instances found."
    exit 0
fi

# Count how many Fish instances we found
fish_count=$(echo "$fish_pids" | wc -l)

# Copy reload command to clipboard (safe approach)
echo "source ~/.config/fish/config.fish" | wl-copy

# Notify user
notify-send -h string:x-canonical-private-synchronous:sys-notify "Fish Shell" "Reload command copied to clipboard 📋\nPaste in each terminal ($fish_count running): Ctrl+Shift+V"
