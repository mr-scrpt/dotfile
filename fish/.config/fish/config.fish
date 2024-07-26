if status is-interactive
    # Commands to run in interactive sessions can go here

    neowofetch
    starship init fish | source
    zoxide init fish | source

    # greeting disabled
    set -g fish_greeting


    # aliases

    alias c="clear"

    if type -q eza
        alias ll "eza -l -g --icons"
        alias lla "ll -a"
    end

    command -qv nvim && alias v nvim

    # EDITOR
    set -gx EDITOR nvim

    #PATH

    set -gx PATH bin $PATH
    set -gx PATH ~/bin $PATH
    set -gx PATH ~/.local/bin $PATH
    set -gx PATH ~/.config/bin $PATH
    set -x PATH $HOME/.cargo/bin $PATH

      # ordered by priority - bottom up
    fish_add_path $HOME/.local/bin
    fish_add_path $HOME/.local/share/nvim/site/pack
end
