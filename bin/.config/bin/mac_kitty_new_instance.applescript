#!/usr/bin/osascript

-- Проверяем, запущен ли процесс Kitty
tell application "System Events"
    set isRunning to (exists process "kitty")
end tell

-- Если Kitty не запущен, запускаем его
if not isRunning then
    tell application "kitty"
        activate
    end tell
else
    -- Если Kitty уже запущен, открываем новый инстанс
    tell application "System Events"
        tell process "kitty"
            -- Используем сочетание клавиш Cmd+N для нового окна
            -- Можно заменить на click menu item, если в Kitty есть меню
            key code 45 using {command down}
        end tell
    end tell
end if
