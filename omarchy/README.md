# omarchy — shell.json, menu extensions, bar plugins mr.big-monitor / mr.local-llm

Both bar icons are proper plugins (`~/.config/omarchy/plugins/<id>/manifest.json + Widget.qml`)
built on `BarWidget` + `BarIconButton`, so they get the stock icon slot/canvas/font and
theme colours for free. Toggle look = stock indicators: `useActiveColor: false` +
`dimmed: !on` (never `active: true` alone — that paints the icon in `bar.urgent`, red).

## mr.local-llm — llama.cpp model state

`llama-local-status` JSON -> dim (off) / blinking (loading) / green (ready).
Left click `hermes-local-launch`, right click `llama-local-status toggle`.

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
