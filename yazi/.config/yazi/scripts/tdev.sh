#!/bin/sh
cd "$1" || exit 1
tmux new -s "$2" -d
tmux select-window -t 1
tmux rename-window ' editor'
tmux send-keys -t "$pane" 'nvim' Enter

tmux new-window;
tmux rename-window ' server'
tmux send-keys -t "$pane"

tmux new-window;
tmux rename-window ' terminal'
tmux send-keys -t "$pane"

tmux new-window;
tmux rename-window ' infra'
tmux send-keys -t "$pane"

tmux new-window;
tmux rename-window '🐳 docker'
tmux send-keys -t "$pane"

tmux new-window;
tmux rename-window ' file-manager'
tmux send-keys -t "$pane"

tmux select-window -t 1
# tmux split-window -v 'ipython'
# tmux split-window -h
# tmux new-window 'mutt'
tmux -2 attach-session -d

