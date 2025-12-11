function tmux-clean
    set -l cleaned 0
    # Common Default Locations for tmux-resurrect
    set -l possible_paths \
        "$HOME/.tmux/resurrect" \
        "$HOME/.local/share/tmux/resurrect" \
        "$HOME/.config/tmux/resurrect"

    # 1. Clean files
    for p in $possible_paths
        if test -d "$p"
            echo "Found session data in: $p"
            rm -rf "$p"
            mkdir -p "$p"
            set cleaned 1
        end
    end

    # 2. Kill the running server (Memory flush)
    # Check if tmux is running first to avoid ugly error messages
    if pgrep -x tmux >/dev/null
        echo "Killing running tmux server to clear memory state..."
        tmux kill-server
    else
        echo "Tmux server is not running."
    end

    if test $cleaned -eq 1
        echo "Tmux session history has been cleaned and server killed."
    else
        echo "No tmux session files found, but server check was performed."
    end
end
