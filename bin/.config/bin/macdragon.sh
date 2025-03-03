#!/bin/bash
# ~/.config/bin/macdragon.sh

# Создаем директорию для логов
mkdir -p ~/tmp/dragon

# Логирование для отладки
echo "macdragon.sh запущен с аргументами: $@" > ~/tmp/dragon/macdragon_log.txt
echo "Количество аргументов: $#" >> ~/tmp/dragon/macdragon_log.txt

# Проверяем, что получили аргументы
if [ $# -eq 0 ]; then
    echo "Ошибка: не указаны файлы" >> ~/tmp/dragon/macdragon_log.txt
    exit 1
fi

# Проверяем каждый аргумент
for arg in "$@"; do
    echo "Аргумент: $arg" >> ~/tmp/dragon/macdragon_log.txt
    if [ ! -e "$arg" ]; then
        echo "Файл не существует: $arg" >> ~/tmp/dragon/macdragon_log.txt
    fi
done

# Вызываем AppleScript только с существующими файлами
VALID_FILES=()
for arg in "$@"; do
    if [ -e "$arg" ]; then
        VALID_FILES+=("$arg")
    fi
done

if [ ${#VALID_FILES[@]} -eq 0 ]; then
    echo "Нет действительных файлов для обработки" >> ~/tmp/dragon/macdragon_log.txt
    exit 1
fi

echo "Запуск AppleScript с действительными файлами: ${VALID_FILES[@]}" >> ~/tmp/dragon/macdragon_log.txt
osascript ~/.config/bin/macdragon.applescript "${VALID_FILES[@]}" >> ~/tmp/dragon/macdragon_log.txt 2>&1
