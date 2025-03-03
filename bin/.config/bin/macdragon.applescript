on run argv
    -- Создаем базовую директорию для временных папок, если она не существует
    do shell script "mkdir -p ~/tmp/dragon"

    -- Создаем имя для временной папки в формате macdragon_число_месяц_год_инкремент
    set dateStr to do shell script "date +'%d_%m_%Y'"

    -- Определяем инкрементный номер для текущего дня
    set dayCounterFile to (do shell script "echo $HOME/tmp/dragon/.counter_" & dateStr)

    -- Проверяем существование счетчика и создаем/инкрементируем его
    if (do shell script "[ -f " & quoted form of dayCounterFile & " ] && echo 1 || echo 0") is equal to "1" then
        set counterValue to (do shell script "cat " & quoted form of dayCounterFile)
        set counterValue to counterValue + 1
    else
        set counterValue to 1
    end if

    -- Обновляем значение счетчика
    do shell script "echo " & counterValue & " > " & quoted form of dayCounterFile

    -- Формируем имя папки
    set tempFolderName to "macdragon_" & dateStr & "_" & counterValue
    set tempFolder to (do shell script "echo $HOME/tmp/dragon/" & tempFolderName)

    -- Создаем временную папку
    do shell script "mkdir -p " & quoted form of tempFolder

    -- Создаем ссылки на все файлы во временной папке
    repeat with i from 1 to count of argv
        set filePath to item i of argv
        set fileName to do shell script "basename " & quoted form of filePath
        do shell script "ln -s " & quoted form of filePath & " " & quoted form of (tempFolder & "/" & fileName)
    end repeat

    -- Открываем временную папку в Finder с минимальным интерфейсом
    tell application "Finder"
        set tempFolderPath to POSIX file tempFolder as string
        open tempFolderPath
        activate
        set targetWindow to window 1

        -- Настраиваем вид окна
        set current view of targetWindow to list view
        set sidebar width of targetWindow to 0
        set toolbar visible of targetWindow to false
        set statusbar visible of targetWindow to false
        set the bounds of targetWindow to {100, 100, 500, 400}

        -- Выбираем все элементы
        set targetFolder to folder tempFolderPath
        set theItems to every item of targetFolder
        select theItems
    end tell

    -- Запускаем отдельный процесс для очистки через 5 минут
    do shell script "nohup bash -c 'sleep 300; rm -rf " & quoted form of tempFolder & "' > /dev/null 2>&1 &"
end run
