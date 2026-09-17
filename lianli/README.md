# Lian Li — полный сетап (Arch + Hyprland)

Всё управление железом Lian Li: подсветка, вентиляторы, помпа, LCD-экраны.
Софт: [lianli-linux](https://github.com/sgtaziz/lian-li-linux) (AUR
`lianli-linux-git`) + OpenRGB (мать/RAM/GPU) + свои сервисы.

## Состав

```
.config/lianli/              # конфиги демона lianli
  config.json                #   устройства, экраны, AIO (тема 7, rotation)
  lcd_templates.json         #   8 кастомных шаблонов (5 кулеров + 3 для 8.8")
  media/                     #   фоны (космос) и белые трафареты экранов
  scripts/                   #   сенсорные скрипты (ping, net-rate и др.)
  presets/lcds-backup.json   #   бэкап LCD-настроек для пресета "LCD On"
.config/OpenRGB/             # профиль cyan, sizes.ors (размеры зон), отключённые детекторы Lian Li
.config/systemd/user/
  lianli-sensor-service.service   # публикует датчики в /tmp/lianli-sensors/
  openrgb-profile.service         # OpenRGB SDK-сервер + профиль cyan
  rgb-runway.service              # бегущий белый по кольцам/RAM + перезаливка
  lianli-rgb-apply.service        # переприменение RGB после загрузки
.local/share/lianli-presets/ # preset.py (light/lcd on/off), apply_rgb.py (apply/reset)
.local/share/rgb-runway/     # runway_extra.py (стример эффекта)
.local/share/applications/   # 5 пунктов меню: Light On/Off, LCD On/Off, Reset
.local/share/fonts/bebas_neue/ # шрифт для шаблонов 8.8"
sensor-service/              # исходники lianli-sensor-service (Rust)
```

## Развёртывание на чистой системе

```bash
omarchy pkg add openrgb i2c-tools
# lianli-linux: пока держим v0.9.1 — в v1.0.0 появился лимит 256 MiB на видео-виджет,
# нативная анимация L-Connect для 8.8" (26 с, 1920x480) в него не влезает.
# https://github.com/sgtaziz/lian-li-linux/issues/207 — после фикса: omarchy pkg aur add lianli-linux-git
#   сборка 0.9.1: PKGBUILD из AUR (коммит до 1.0.0), source=...#tag=v0.9.1, makepkg -si
omarchy install dev-env rust
cd ~/Hellkitchen/dotfile
stow -t ~ lianli
lianli-state install                      # config.json + lcd_templates.json (демон не принимает симлинки)
(cd lianli-src && cargo build --release && install -Dm755 target/release/lianli-sensor-service ~/.local/bin/)
fc-cache -f                               # Bebas Neue для 8.8"
uv venv ~/.local/share/lianli-venv && uv pip install --python ~/.local/share/lianli-venv/bin/python openrgb-python
systemctl --user daemon-reload
systemctl --user disable --now lianli-session   # desktop-capture для 8.8" не используем
systemctl --user enable --now lianli-daemon lianli-sensor-service openrgb-profile rgb-runway lianli-rgb-apply
```

После правок в lianli-gui: `lianli-state save` и коммит.

Цвет: циан #00D7FF (0,215,255), бегунок белый. Runway на Strimer: цвета
в конфиге [белый, циан] — у него первый цвет это бегунок.
