if status is-interactive
    if test -f ~/.config/fish/env.fish
        source ~/.config/fish/env
    end

    if test -f ~/.config/fish/path.fish
        source ~/.config/fish/path.fish
    end
    # Commands to run in interactive sessions can go here
    set -g fish_greeting
    fish_vi_key_bindings
    atuin init fish | source
    clear
    fastfetch
end
