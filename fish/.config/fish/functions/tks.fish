function tks -d "Kill tmux server if it is running"
    if tmux has-session 2>/dev/null
        tmux kill-server
        echo "Tmux server killed."
    else
        echo "No running tmux server found."
    end
end
