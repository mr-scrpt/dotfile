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
.config/OpenRGB/             # профиль cyan + отключённые детекторы Lian Li
.config/systemd/user/
  lianli-sensor-service.service   # публикует датчики в /tmp/lianli-sensors/
  openrgb-profile.service         # OpenRGB SDK-сервер + профиль cyan
  rgb-runway.service              # бегущий белый по кольцам/RAM + перезаливка
  lianli-rgb-apply.service        # переприменение RGB после загрузки
  lianli-daemon.service.d/hw-video.conf  # NVENC для 8.8" (LIANLI_ENABLE_HW_VIDEO)
.local/share/lianli-presets/ # preset.py (light/lcd on/off), apply_rgb.py (apply/reset)
.local/share/rgb-runway/     # runway_extra.py (стример эффекта)
.local/share/applications/   # 5 пунктов меню: Light On/Off, LCD On/Off, Reset
sensor-service/              # исходники lianli-sensor-service (Rust)
```

## Развёртывание на чистой системе

```bash
yay -S lianli-linux-git openrgb i2c-tools
cd ~/Hellkitchen/dotfile && stow lianli   # или скопировать вручную
# собрать sensor-service:
cd lianli/sensor-service && cargo build --release
install -Dm755 target/release/lianli-sensor-service ~/.local/bin/
# шрифт для шаблона 8.8" (Bebas Neue -> ~/.local/share/fonts/bebas_neue/)
# venv для скриптов:
uv venv ~/.local/share/rgb-runway/venv
uv pip install --python ~/.local/share/rgb-runway/venv/bin/python openrgb-python
systemctl --user daemon-reload
systemctl --user enable --now lianli-daemon lianli-sensor-service \
  openrgb-profile rgb-runway lianli-rgb-apply
```

Цвет: циан #00D7FF (0,215,255), бегунок белый. Runway на Strimer: цвета
в конфиге [белый, циан] — у него первый цвет это бегунок.
