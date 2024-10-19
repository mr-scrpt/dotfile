if status is-interactive
    # Commands to run in interactive sessions can go here
    # eval (ssh-agent -c)

    neofetch
    starship init fish | source
    zoxide init fish | source

    # greeting disabled
    set -g fish_greeting


    # aliases

    alias c="clear"
    # alias pgadmin4="sudo python3 /usr/lib/pgadmin4/pgAdmin4.py"
    # alias y="yazi"


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

# pnpm
set -gx PNPM_HOME "/home/mr/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
