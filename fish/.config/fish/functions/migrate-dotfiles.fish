function migrate-dotfiles --description "Migrate config directory to dotfiles structure and apply stow"
    # Цвета для вывода
    set -l RED (set_color red)
    set -l GREEN (set_color green)
    set -l YELLOW (set_color yellow)
    set -l BLUE (set_color blue)
    set -l NORMAL (set_color normal)

    # Функции для вывода сообщений
    function print_info
        echo "$BLUE[INFO]$NORMAL $argv"
    end

    function print_success
        echo "$GREEN[SUCCESS]$NORMAL $argv"
    end

    function print_warning
        echo "$YELLOW[WARNING]$NORMAL $argv"
    end

    function print_error
        echo "$RED[ERROR]$NORMAL $argv"
    end

    # Функция помощи
    function show_help
        echo "Использование: migrate-dotfiles <catalog_name> [options]"
        echo ""
        echo "Этот скрипт перемещает каталог из ~/.config/{catalog_name} в ~/dotfiles/{catalog_name}/.config/{catalog_name}"
        echo "и затем запускает stow для создания символических ссылок."
        echo ""
        echo "Аргументы:"
        echo "  catalog_name    Имя каталога для перемещения"
        echo ""
        echo "Опции:"
        echo "  -h, --help      Показать это сообщение помощи"
        echo "  -f, --force     Принудительно перезаписать существующие файлы"
        echo "  -n, --dry-run   Показать что будет сделано, но не выполнять действия"
        echo "  -b, --backup    Создать резервную копию перед перемещением"
        echo ""
        echo "Примеры:"
        echo "  migrate-dotfiles hypr                    # Переместить ~/.config/hypr"
        echo "  migrate-dotfiles waybar --force          # Принудительно переместить ~/.config/waybar"
        echo "  migrate-dotfiles nvim --dry-run          # Показать что будет сделано с ~/.config/nvim"
        echo "  migrate-dotfiles alacritty --backup      # Создать резервную копию перед перемещением"
    end

    # Инициализация переменных
    set -l force false
    set -l dry_run false
    set -l backup false
    set -l catalog_name ""

    # Парсинг аргументов
    argparse h/help f/force n/dry-run b/backup -- $argv
    or return 1

    # Проверка опций
    if set -q _flag_help
        show_help
        return 0
    end

    if set -q _flag_force
        set force true
    end

    if set -q _flag_dry_run
        set dry_run true
    end

    if set -q _flag_backup
        set backup true
    end

    # Проверка наличия обязательного аргумента
    if test (count $argv) -eq 0
        print_error "Не указано имя каталога"
        show_help
        return 1
    else if test (count $argv) -gt 1
        print_error "Слишком много аргументов"
        show_help
        return 1
    end

    set catalog_name $argv[1]

    # Определение путей
    set -l config_source "$HOME/.config/$catalog_name"
    set -l dotfiles_dir "$HOME/dotfiles"
    set -l dotfiles_catalog "$dotfiles_dir/$catalog_name"
    set -l dotfiles_config "$dotfiles_catalog/.config"
    set -l dotfiles_target "$dotfiles_config/$catalog_name"

    print_info "Начинаю обработку каталога: $catalog_name"

    # Проверка существования исходного каталога
    if not test -d "$config_source"
        print_error "Каталог $config_source не существует"
        return 1
    end

    # Проверка наличия stow
    if not command -q stow
        print_error "stow не установлен. Установите его с помощью пакетного менеджера"
        return 1
    end

    # Создание директории dotfiles если не существует
    if not test -d "$dotfiles_dir"
        print_info "Создаю директорию $dotfiles_dir"
        if test "$dry_run" = false
            mkdir -p "$dotfiles_dir"
        end
    end

    # Проверка существования целевого каталога
    if test -d "$dotfiles_target"
        if test "$force" = false
            print_warning "Каталог $dotfiles_target уже существует"
            read -P "Хотите продолжить? (y/N): " -n 1 response
            echo
            if not string match -qi "y*" "$response"
                print_info "Операция отменена"
                return 0
            end
        end
    end

    # Создание резервной копии если запрошено
    if test "$backup" = true -a -d "$config_source"
        set -l backup_path "$config_source.backup."(date +%Y%m%d_%H%M%S)
        print_info "Создаю резервную копию: $backup_path"
        if test "$dry_run" = false
            cp -r "$config_source" "$backup_path"
            and print_success "Резервная копия создана: $backup_path"
        end
    end

    # Dry run информация
    if test "$dry_run" = true
        print_info "=== DRY RUN MODE ==="
        print_info "Будут выполнены следующие действия:"
        echo "1. Создать директорию: $dotfiles_config"
        echo "2. Переместить: $config_source -> $dotfiles_target"
        echo "3. Выполнить: stow -d $dotfiles_dir $catalog_name"
        return 0
    end

    # Создание структуры директорий
    print_info "Создаю структуру директорий в $dotfiles_config"
    mkdir -p "$dotfiles_config"

    # Перемещение каталога
    print_info "Перемещаю $config_source в $dotfiles_target"
    if mv "$config_source" "$dotfiles_target"
        print_success "Каталог успешно перемещен"
    else
        print_error "Ошибка при перемещении каталога"
        return 1
    end

    # Применение stow
    print_info "Применяю stow для $catalog_name"
    set -l current_dir (pwd)
    cd "$dotfiles_dir"
    or begin
        print_error "Не удалось перейти в директорию $dotfiles_dir"
        return 1
    end

    if stow "$catalog_name"
        print_success "stow успешно применен"
        print_info "Символическая ссылка создана: ~/.config/$catalog_name -> $dotfiles_target"
    else
        print_error "Ошибка при применении stow"
        # Попытка отката
        print_info "Пытаюсь откатить изменения..."
        if mv "$dotfiles_target" "$config_source"
            print_success "Изменения откатаны"
        else
            print_error "Не удалось откатить изменения. Каталог находится в $dotfiles_target"
        end
        cd "$current_dir"
        return 1
    end

    cd "$current_dir"

    print_success "Операция завершена успешно!"
    print_info "Каталог $catalog_name теперь управляется через dotfiles"
    print_info "Для отмены используйте: stow -D $catalog_name"
end
