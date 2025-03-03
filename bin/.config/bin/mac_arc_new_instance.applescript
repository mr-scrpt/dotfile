#!/usr/bin/osascript

-- Проверяем, запущен ли процесс Arc
tell application "System Events"
    set isRunning to (exists process "Arc")
end tell

-- Если Arc не запущен, запускаем его
if not isRunning then
    tell application "Arc"
        activate
    end tell
else
    -- Если Arc уже запущен, открываем новое окно
    tell application "System Events"
        tell process "Arc"
            click menu item "New Window" of menu "File" of menu bar 1
        end tell
    end tell
end if
