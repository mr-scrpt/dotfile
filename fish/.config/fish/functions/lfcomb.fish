# Wrapper script for lf with ueberzug and lfcd functionality
function lfcomb
    set UB_PID 0
    set UB_SOCKET ""

    switch (uname -s)
        case Darwin
            set UEBERZUG_TMP_DIR "$TMPDIR"
        case '*'
            set UEBERZUG_TMP_DIR "/tmp"
    end

    function cleanup
        exec 3>&-
        ueberzugpp cmd -s "$UB_SOCKET" -a exit
    end

    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]
        command lf $argv
    else
        [ ! -d "$HOME/.cache/lf" ] && mkdir -p "$HOME/.cache/lf"
        set UB_PID_FILE "$UEBERZUG_TMP_DIR/.$(uuidgen)"
        ueberzugpp layer --silent --no-stdin --use-escape-codes --pid-file "$UB_PID_FILE"
        set UB_PID (cat "$UB_PID_FILE")
        rm "$UB_PID_FILE"
        set UB_SOCKET "$UEBERZUG_TMP_DIR/ueberzugpp-$UB_PID.socket"
        export UB_PID UB_SOCKET
        trap cleanup HUP INT QUIT TERM EXIT

        # Check if 'lfcd' is available in the current shell
        if functions -q lfcd
            lfcd
        else
            command lf $argv
        end
    end
end

