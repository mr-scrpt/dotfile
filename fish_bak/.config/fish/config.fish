if status is-interactive
    # Commands to run in interactive sessions can go here

  # neofetch
  neowofetch
  starship init fish | source
  zoxide init fish | source
# Only start tmux if not already running
if type -q tmux
  if not tmux has-session &>/dev/null
    # Start tmux server
    tmux start-server
    # Create a new session to initialize the server
    # tmux new-session -d -s main
    # Restore tmux sessions
    # tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh
    tmux run-shell ~/.tmux/plugins/tmux-resurrect/resurrect.tmux
  end
end

  # aliases
  # alias lf="lfcomb"
  alias c="clear"

  if type -q eza
    alias ll "eza -l -g --icons"
    alias lla "ll -a"
  end

  command -qv nvim && alias v nvim

  # restore fzf default options ('fzf clear')
  # alias fzfcl='set -U FZF_DEFAULT_COMMAND "fd ."'

# reinstate fzf custom options ('fzf-' as in 'cd -' as in 'back to where I was')
  # alias fzf='set -U FZF_DEFAULT_COMMAND "fd . \$HOME"'

  set -x FZF_CTRL_R_OPTS "--border-label=' History ' --prompt=' '"
  # set -U FZF_DEFAULT_COMMAND "fd -H -E '.git'"
  set -x FZF_DEFAULT_COMMAND "fd . \$HOME -H -E '.git'"

  set -x FZF_DEFAULT_OPTS "--reverse --no-info --prompt=' ' --pointer='' --marker=' ' --ansi --color gutter:-1,bg+:-1,header:4,separator:0,info:0,label:4,border:4,prompt:7,pointer:5,query:7,prompt:7"
  set -x FZF_TMUX_OPTS "-p --no-info --ansi --color gutter:-1,bg+:-1,header:4,separator:0,info:0,label:4,border:4,prompt:7,pointer:5,query:7,prompt:7"


  set -gx fish_greeting # disable fish greeting
  set -U BAT_THEME Nord # 'sharkdp/bat' cat clone
  set -U EDITOR nvim # 'neovim/neovim' text editor

  #FZF

  #PATH
  set -gx PATH bin $PATH
  set -gx PATH ~/bin $PATH
  set -gx PATH ~/.local/bin $PATH
  set -gx PATH ~/.config/tmux/bin $PATH
  set -gx PATH ~/.config/bin $PATH

  # ordered by priority - bottom up
  fish_add_path /opt/homebrew/bin # https://brew.sh/
  fish_add_path /opt/homebrew/sbin
  fish_add_path $HOME/.local/bin
  fish_add_path $HOME/.local/share/nvim/site/pack

end

