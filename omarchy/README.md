# omarchy — shell.json, bar modules, menu extensions, plugin mr.big-monitor

## mr.big-monitor — big monitor (DP-1) on/off from the bar

```
omarchy/.config/omarchy/plugins/mr.big-monitor/  # bar widget (manifest.json + Widget.qml)
bin/.local/bin/omarchy-big-monitor                # on|off|toggle|status: flag + hyprctl reload
hypr/.config/hypr/monitors.lua                    # reads the flag, sets monitors + workspace rules
```

Flag: `$XDG_RUNTIME_DIR/omarchy-big-monitor-enabled` -> off after every reboot.

Workspaces: one monitor -> all on HDMI-A-1. Big monitor on -> 1-5 stay on
HDMI-A-1 (below, centered), 6-10 bound to DP-1 (on top); `on` also moves
already-existing workspaces >= 6 there.

Bar entry `{"id": "mr.big-monitor"}` sits in `bar.layout.right` before `omarchy.monitor`.
Check: `omarchy plugin list | grep big-monitor` -> enabled.
