# Ghostty Configuration Reload

## 🎯 Сводка

Ghostty - современный терминальный эмулятор с мощными возможностями, но пока без прямой CLI команды для перезагрузки конфигурации во всех окнах.

## 📊 Сравнение с Fish

| Аспект | Fish Shell | Ghostty Terminal |
|--------|-----------|------------------|
| Архитектура | Независимые процессы | Приложение с множественными окнами |
| IPC система | ❌ Нет | ✅ Есть (используется в `+new-window`) |
| reload_config действие | ❌ Нет | ✅ Есть |
| CLI команда для reload | ❌ Нет | ❌ Пока нет (`ghostty +reload-config` в обсуждении) |
| Keybind для reload | ⚠️ Ручной `source` | ✅ Ctrl+Shift+, (запятая) |

## 🔍 Текущие возможности Ghostty

### Встроенный Reload
Ghostty имеет встроенное действие `reload_config`, привязанное к:
- **Linux**: `Ctrl + Shift + ,` (comma)
- **macOS**: `Cmd + Shift + ,`

### IPC система
Ghostty имеет систему межпроцессного взаимодействия (IPC), которая используется для:
- ✅ `ghostty +new-window` - открыть новое окно в существующем instance
- ✅ Управление tabs и splits
- ❌ **Reload config пока не доступен через IPC**

### Будущие возможности
На GitHub есть обсуждение о добавлении [CLI команды для reload](https://github.com/ghostty-org/ghostty/issues/), что позволит делать:
```bash
ghostty +reload-config  # Планируемая функция
```

## 🛠️ Текущее решение

### Скрипт `ghostty.sh`

Скрипт делает следующее:
1. Проверяет количество открытых окон Ghostty через `hyprctl`
2. Показывает информативное уведомление с напоминанием о keybind
3. Пользователь нажимает `Ctrl+Shift+,` в каждом окне Ghostty

```bash
#!/usr/bin/env bash

# Найти все окна Ghostty
ghostty_count=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address' | wc -l)

if [ "$ghostty_count" -eq 0 ]; then
    notify-send "Ghostty" "No running Ghostty windows found."
    exit 0
fi

# Показать уведомление
notify-send "Ghostty" "To reload config in each window ($ghostty_count running):\nPress Ctrl+Shift+, (comma) 👻"
```

## 💡 Альтернативные подходы (рассмотренные и отвергнутые)

### Вариант 1: Автоматизация через ydotool ❌
**Идея**: Использовать `ydotool` для автоматической отправки Ctrl+Shift+, всем окнам

**Проблемы**:
- Требует установки и настройки `ydotool`
- Необходим запущенный `ydotoold` daemon
- Сложная настройка прав доступа для Wayland
- Может быть ненадежно (задержки, race conditions)
- Слишком сложно для простой задачи

### Вариант 2: Автоматизация через xdotool (только X11) ❌
**Проблемы**:
- Не работает на Wayland (у вас Hyprland)
- Устаревший подход

### Вариант 3: Обходной путь через перезапуск ❌
**Идея**: Закрыть и перезапустить все Ghostty windows

**Проблемы**:
- Потеря состояния (scrollback, tabs, splits)
- Потеря истории команд активных сессий
- Прерывание работающих процессов

### Вариант 4: Текущий (информативное уведомление) ✅
**Преимущества**:
- ✅ Простой и надежный
- ✅ Не требует дополнительных зависимостей
- ✅ Показывает количество окон
- ✅ Напоминает правильный keybind
- ✅ Когда Ghostty добавит '+reload-config', легко обновить скрипт

## 🚀 Использование

Запустите через меню reload:
```bash
bash /home/mr/temp/hypr/custom/scripts/reload/menu-reload.sh
```

Выберите "👻 Ghostty Config":
1. Получите уведомление о количестве открытых окон
2. Перейдите в каждое окно Ghostty
3. Нажмите `Ctrl + Shift + ,` (comma)
4. Конфиг перезагружен! ✨

## 📝 Примечания

### Какие изменения конфига перезагружаются?
Большинство изменений перезагружаются на лету, но некоторые могут требовать:
- Создания нового терминала (tab/split)
- Полного перезапуска Ghostty

Подробности в [документации Ghostty](https://ghostty.org/).

### Можно ли автоматизировать полностью?
**Пока нет**, но следите за:
- [GitHub Ghostty Issues](https://github.com/ghostty-org/ghostty/issues) - обсуждение `+reload-config`
- Обновления Ghostty - IPC API расширяется

## 🔮 Будущие улучшения

Когда Ghostty добавит `+reload-config`, скрипт будет обновлен до:
```bash
#!/usr/bin/env bash

# Find Ghostty instances
if ! ghostty_count=$(ghostty +instance-count 2>/dev/null); then
    notify-send "Ghostty" "No running instances."
    exit 0
fi

# Send reload command to all instances
ghostty +reload-config

notify-send "Ghostty" "Configuration reloaded in all instances 👻"
```

## 🆚 Итоговое сравнение решений

| Инструмент | Метод reload | Автоматизация | Примечания |
|------------|--------------|---------------|------------|
| **Tmux** | `tmux source-file` | ✅ Полная | Единый сервер, все сессии обновляются |
| **Fish** | Копирование команды | ⚠️ Полуавтоматическая | Нет центрального управления |
| **Ghostty** | Keybind подсказка | ⚠️ Полуавтоматическая | IPC есть, но reload пока не поддерживается |
| **Waybar** | `killall -SIGUSR2` | ✅ Полная | Классический UNIX подход |
| **Hyprland** | `hyprctl reload` | ✅ Полная | Встроенная команда |

## 💬 Заключение

Для Ghostty **текущий подход с уведомлением - это оптимальное решение** до тех пор, пока не будет добавлена официальная поддержка CLI reload. Это:
- Простое и надежное
- Не требует дополнительных зависимостей
- Легко обновляется когда появится нужная функция
- Информативное (показывает количество окон)

Простое напоминание лучше, чем сложная и ненадежная автоматизация! 👍
