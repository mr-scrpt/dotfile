# Очистка старых промптов Tide при старте
if set -q _tide_left_items
    for var in (set -U --names | string match '_tide_prompt_*')
        set -e -U $var
    end
end
if status is-interactive
    if test -f ~/.config/fish/env.fish
        source ~/.config/fish/env.fish
    end

    if test -f ~/.config/fish/path.fish
        source ~/.config/fish/path.fish
    end
    # Commands to run in interactive sessions can go here
    set -g fish_greeting
    zoxide init fish | source
    # fish_vi_key_bindings
    atuin init fish | source
    mise activate fish | source
    clear
    fastfetch

    alias v="nvim"

    # # 1. Исправляем Ctrl+Backspace (удаление слова)
    # bind -M insert ctrl-backspace backward-kill-word
    # bind -M default ctrl-backspace backward-kill-word
    #
    # # 2. Исправляем Shift+Enter (новая строка без выполнения)
    # bind -M insert shift-enter 'commandline -i \n'
    #
    # # 3. Исправляем Ctrl+Стрелки (навигация по словам)
    # bind -M insert ctrl-right forward-word
    # bind -M insert ctrl-left backward-word
    # bind -M default ctrl-right forward-word
    # bind -M default ctrl-left backward-word
end

# opencode
fish_add_path /home/mr/.opencode/bin
starship init fish | source
