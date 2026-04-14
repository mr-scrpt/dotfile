# =============================================================================
# 1. Очистка старых промптов (Tide)
# =============================================================================
if set -q _tide_left_items
    for var in (set -U --names | string match '_tide_prompt_*')
        set -e -U $var
    end
end

# =============================================================================
# 2. Базовые пути и переменные
# =============================================================================
# Подгружаем пользовательские переменные окружения и пути
if test -f ~/.config/fish/env.fish
    source ~/.config/fish/env.fish
end
if test -f ~/.config/fish/path.fish
    source ~/.config/fish/path.fish
end
if test -z "$WAYLAND_DISPLAY"
    for s in /run/user/1000/wayland-*
        if test -S $s; and not string match -q "*.lock" $s
            set -gx WAYLAND_DISPLAY (basename $s)
            break
        end
    end
end
# Добавляем пути внешних инструментов
# opencode
fish_add_path /home/mr/.opencode/bin
fish_add_path ~/.local/bin
# pnpm
set -gx PNPM_HOME "/home/mr/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end

# =============================================================================
# 3. Менеджер окружений (mise) — МАКСИМАЛЬНЫЙ ПРИОРИТЕТ ПУТЕЙ
# =============================================================================
# Флаг -m (move) принудительно выдергивает путь к shims (прослойкам) из любого
# места и ставит его в САМОЕ НАЧАЛО $PATH. Это гарантирует, что mise перехватит
# команду `node` раньше, чем Fish дойдет до /usr/bin/node.
fish_add_path -m ~/.local/share/mise/shims

# =============================================================================
# 4. Claude Code — настройки AI-ассистента
# =============================================================================
# Fullscreen rendering: фиксирует поле ввода внизу экрана, история скролится
# независимо. Требует Claude Code v2.1.89+
# set -gx CLAUDE_CODE_NO_FLICKER 1
# set -gx CLAUDE_CODE_DISABLE_MOUSE 1

# =============================================================================
# 5. Интерактивная сессия (Биндинги, Алиасы, Промпт, Утилиты)
# =============================================================================
if status is-interactive
    # Отключение стандартного приветствия
    set -g fish_greeting
    # Активация хуков mise для автодополнения и динамической подмены окружения
    mise activate fish | source
    # Инициализация Zoxide (умный cd)
    zoxide init fish | source
    # Инициализация Atuin (история команд)
    atuin init fish | source
    # Инициализация Starship (Промпт загружается в конце, чтобы видеть все пути)
    starship init fish | source
    # Настройка VI-режима и привязок клавиш
    fish_vi_key_bindings
    function fish_user_key_bindings
        # Сначала грузим дефолтные vi-биндинги
        fish_vi_key_bindings
        # 1. Ctrl+Backspace
        bind -M insert ctrl-backspace backward-kill-word
        bind -M default ctrl-backspace backward-kill-word
        # 2. Shift+Enter
        bind -M insert shift-enter 'commandline -i \n'
        # 3. Ctrl+Arrows
        bind -M insert ctrl-right forward-word
        bind -M insert ctrl-left backward-word
    end
    # Визуальная очистка и системная информация
    clear
    fastfetch
    # Алиасы
    alias v="nvim"
end

# =============================================================================
# 6. Алиасы (глобальные)
# =============================================================================
# Claude Code
alias cs='claude-statusbar'
alias cstatus='claude-statusbar'
