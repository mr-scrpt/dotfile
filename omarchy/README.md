# omarchy — пользовательский слой Omarchy 4 (omarchy-shell)

```
.config/omarchy/
  plugins/mr.big-monitor/     # свой bar-виджет: вкл/выкл большой монитор DP-1 (AORUS FO48U)
  shell.json                  # раскладка бара (mr.big-monitor справа перед omarchy.monitor), idle-таймеры
  extensions/omarchy-menu.jsonc  # пункты меню: TG Videos, Reboot to Windows
  hooks/theme-set.d/10-layout-border-color.sh  # перезапуск layout_border_color при смене темы
  themes/tokyo-night/hyprland.lua  # цвета рамок + прозрачность терминала для темы
  branding/                   # about.txt, screensaver.txt
.local/bin/omarchy-big-monitor  # on|off|toggle|status; флаг в $XDG_RUNTIME_DIR, монитор выключен после ребута
```

Виджет читает состояние из Hyprland.monitors, по клику вызывает
`omarchy-big-monitor toggle`, который ставит/снимает флаг и делает `hyprctl reload`.
Раскладка мониторов с учётом флага — в `hypr/.config/hypr/monitors.lua`
(DP-1 сверху 0x0, HDMI-A-1 снизу 320x1080 при включённом; иначе DP-1 disabled).

## Восстановление

```bash
cd ~/Hellkitchen/dotfile && stow omarchy hypr bin foot git
omarchy plugin list | grep big-monitor   # должен быть enabled, third-party
omarchy-shell reload                     # или перелогиниться
```
Зависимости пунктов меню: `tg-videos` (~/Work/tg-videos), `reboot-to-windows` (bin).
