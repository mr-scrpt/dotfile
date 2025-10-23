#!/bin/bash
# Toggle script for pass-keyboard-control
# Opens the app if not running, closes if already open

# Check if the window exists using hyprctl
if hyprctl clients | grep -q "Pass Keyboard Control"; then
    # Window exists - close it
    # Get the process ID and kill it
    pkill -f "pass-kb" || pkill -f "pass_client"
else
    # Window doesn't exist - launch it
    pass-kb &
fi
