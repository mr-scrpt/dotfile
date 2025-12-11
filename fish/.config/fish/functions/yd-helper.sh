#!/bin/sh

# Generate a unique session name based on the current directory hash.
# This allows multiple independent yazi-dual sessions for different projects.
# User requested readable name with last 2 path components, e.g. yazi[dir/subdir]

PWD_HASH=$(echo "$PWD" | md5sum | cut -c1-6)
# Extract last 2 directories. handling root or short paths gracefully.
PATH_LABEL=$(echo "$PWD" | rev | cut -d/ -f1-2 | rev)
SESSION_NAME="filemanager [${PATH_LABEL}]_${PWD_HASH}"
YAZI_CONFIG_DIR="$HOME/temp/yazi/dual"

# Using standard yazi command without debug flags for production
YAZI_CMD="YAZI_CONFIG_HOME=$YAZI_CONFIG_DIR yazi"

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # If it exists, just attach
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# If we are here, session doesn't exist. Create it.
# 1. Create detached session (Pane 1 - Shell)
# -u forces UTF-8
tmux -u new-session -d -s "$SESSION_NAME"

# 2. Force passthrough (Good practice for ghostty/yazi)
tmux set-option -t "$SESSION_NAME" allow-passthrough on

# 3. Split window (Pane 2 - Shell)
tmux split-window -h -t "$SESSION_NAME"

# 4. Launch Yazi in both panes
# We use "; exit" to ensure the pane closes automatically when Yazi quits.
tmux send-keys -t "${SESSION_NAME}:1.1" "$YAZI_CMD; exit" C-m
tmux send-keys -t "${SESSION_NAME}:1.2" "$YAZI_CMD; exit" C-m

# 5. Attach
tmux attach-session -t "$SESSION_NAME"
