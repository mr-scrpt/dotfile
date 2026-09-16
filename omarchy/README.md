# Плагин mr.big-monitor — вкл/выкл большой монитор DP-1 из бара Omarchy

```
.config/omarchy/plugins/mr.big-monitor/  # bar-виджет (manifest.json + Widget.qml)
.local/bin/omarchy-big-monitor           # on|off|toggle|status — ставит/снимает флаг и делает hyprctl reload
.config/hypr/monitors.lua                # читает флаг: DP-1 включён (сверху, HDMI-A-1 снизу) или disabled
```

Флаг живёт в `$XDG_RUNTIME_DIR/omarchy-big-monitor-enabled`, поэтому после перезагрузки монитор выключен.

## Восстановление

```bash
cd ~/Hellkitchen/dotfile && stow omarchy
```

Затем добавить виджет в бар: в `~/.config/omarchy/shell.json` в `bar.layout.right`
вставить `{"id": "mr.big-monitor"}` (у нас стоял перед `omarchy.monitor`), либо через
меню Omarchy → Bar. Проверка: `omarchy plugin list | grep big-monitor` → enabled.
