# ~/.config/fish/conf.d/abbrs.fish

if status is-interactive
    abbr -a ta 'tmux a'
    abbr -a ccx 'claude --dangerously-skip-permissions'
    abbr -a ccxr 'claude --dangerously-skip-permissions --continue'
end
