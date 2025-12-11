function tmux-clean
    set -l cleaned 0
    # Common Default Locations for tmux-resurrect
    set -l possible_paths \
        "$HOME/.tmux/resurrect" \
        "$HOME/.local/share/tmux/resurrect" \
        "$HOME/.config/tmux/resurrect"

    for p in $possible_paths
        if test -d "$p"
            echo "Found session data in: $p"
            # Remove the directory and recreate it to avoid wildcard errors with empty dirs
            rm -rf "$p"
            mkdir -p "$p"
            set cleaned 1
        end
    end

    if test $cleaned -eq 1
        echo "Tmux session history (resurrect/continuum) has been cleaned."
    else
        echo "No tmux session data found in standard locations."
    end
end
