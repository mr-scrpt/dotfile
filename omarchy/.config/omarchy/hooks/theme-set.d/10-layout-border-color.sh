#!/bin/bash
# Restart layout_border_color script so it picks up the new theme colors immediately

pkill -f "layout_border_color.sh"
nohup ~/.config/hypr/scripts/layout_border_color.sh >/dev/null 2>&1 &
