#!/bin/bash
pkill -f scroll_layout.sh
sleep 0.5
hyprctl keyword general:layout scrolling
hyprpm reload -n
sleep 0.5
~/.config/hypr/custom/scripts/scroll/scroll_layout.sh &
