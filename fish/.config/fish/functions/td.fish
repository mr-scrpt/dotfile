function td -d "Detach from tmux if inside a tmux session"
    if set -q TMUX
        tmux detach-client
    else
        echo "Not inside a tmux session."
    end
end
