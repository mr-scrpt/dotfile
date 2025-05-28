function tkss -d "Kill all tmux sessions if any exist"
    set sessions (tmux list-sessions 2>/dev/null | cut -d: -f1)
    if test (count $sessions) -eq 0
        echo "No tmux sessions to kill."
        return
    end

    for s in $sessions
        tmux kill-session -t $s
        echo "Killed session: $s"
    end
end
