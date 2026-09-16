#!/bin/bash
MON_BIG="DP-1"
MON_SMALL="HDMI-A-1"
WIDTH_BIG="0.492"
WIDTH_SMALL="0.98"

if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
  HYPR_SIG=$(ls -t $XDG_RUNTIME_DIR/hypr/ | grep -v "\.lock" | head -n 1)
  export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"
fi

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
echo "=== Auto-Scroll: Started ==="

socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
  if [[ "$line" == "focusedmon>>"* ]]; then
    DATA=${line#*>>}
    MON_NAME=${DATA%,*}
    if [[ "$MON_NAME" == "$MON_BIG" ]]; then
      hyprctl keyword scrolling:column_width $WIDTH_BIG >/dev/null # было: plugin:hyprscrolling:column_width
      hyprctl keyword scrolling:focus_fit_method 1 >/dev/null      # было: plugin:hyprscrolling:focus_fit_method
    elif [[ "$MON_NAME" == "$MON_SMALL" ]]; then
      hyprctl keyword scrolling:column_width $WIDTH_SMALL >/dev/null
      hyprctl keyword scrolling:focus_fit_method 0 >/dev/null
    fi
  fi
done
##!/bin/bash
#MON_BIG="DP-1"
#MON_SMALL="HDMI-A-1"
#WIDTH_BIG="0.492"
#WIDTH_SMALL="0.98"
#
#if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
#  HYPR_SIG=$(ls -t $XDG_RUNTIME_DIR/hypr/ | grep -v "\.lock" | head -n 1)
#  export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"
#fi
#SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
#
#echo "=== Auto-Scroll: Started ==="
#
#socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
#  if [[ "$line" == "focusedmon>>"* ]]; then
#    DATA=${line#*>>}
#    MON_NAME=${DATA%,*}
#    if [[ "$MON_NAME" == "$MON_BIG" ]]; then
#      hyprctl keyword plugin:hyprscrolling:column_width $WIDTH_BIG >/dev/null
#      hyprctl keyword plugin:hyprscrolling:focus_fit_method 1 >/dev/null
#    elif [[ "$MON_NAME" == "$MON_SMALL" ]]; then
#      hyprctl keyword plugin:hyprscrolling:column_width $WIDTH_SMALL >/dev/null
#      hyprctl keyword plugin:hyprscrolling:focus_fit_method 0 >/dev/null
#    fi
#  fi
#done
