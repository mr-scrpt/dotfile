# Раскладки панелей herdr — порт $OMARCHY_PATH/default/bash/fns/herdr

function _herdr_ratio --description 'дробь как float'
    awk -v a="$argv[1]" -v b="$argv[2]" 'BEGIN { printf "%.4f", a / b }'
end

function _herdr_split --description 'разделить панель, вернуть id новой'
    herdr pane split "$argv[1]" --direction "$argv[2]" --ratio "$argv[3]" --cwd "$argv[4]" --no-focus |
        jq -r '.result.pane.pane_id'
end

function hdl --description 'раскладка: редактор + агент + терминал'
    if test -z "$argv[1]"
        echo "Usage: hdl <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end
    if test -z "$HERDR_PANE_ID"
        echo "You must start herdr to use hdl."
        return 1
    end

    set -l current_dir $PWD
    set -l ai $argv[1]
    set -l ai2 $argv[2]
    set -l editor_pane $HERDR_PANE_ID

    herdr tab rename "$HERDR_TAB_ID" (basename $current_dir) >/dev/null

    _herdr_split $editor_pane down 0.85 $current_dir >/dev/null
    set -l ai_pane (_herdr_split $editor_pane right 0.7 $current_dir)

    if test -n "$ai2"
        set -l ai2_pane (_herdr_split $ai_pane down 0.5 $current_dir)
        herdr pane run "$ai2_pane" "$ai2" >/dev/null
    end

    herdr pane run "$ai_pane" "$ai" >/dev/null
    herdr pane run "$editor_pane" "$EDITOR ." >/dev/null
end

function hds --description 'квадрат: редактор, diff --watch, терминал, opencode'
    if test -n "$argv[1]"
        echo "Usage: hds"
        return 1
    end
    if test -z "$HERDR_PANE_ID"
        echo "You must start herdr to use hds."
        return 1
    end

    set -l current_dir $PWD
    set -l editor_pane $HERDR_PANE_ID

    herdr tab rename "$HERDR_TAB_ID" (basename $current_dir) >/dev/null

    set -l terminal_pane (_herdr_split $editor_pane down 0.5 $current_dir)
    set -l diff_pane (_herdr_split $editor_pane right 0.5 $current_dir)
    set -l opencode_pane (_herdr_split $terminal_pane right 0.5 $current_dir)

    herdr pane run "$editor_pane" "nvim ." >/dev/null
    herdr pane run "$diff_pane" "hunk diff --watch" >/dev/null
    herdr pane run "$opencode_pane" opencode >/dev/null
end

function hdlm --description 'по вкладке hdl на каждый подкаталог'
    if test -z "$argv[1]"
        echo "Usage: hdlm <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end
    if test -z "$HERDR_PANE_ID"
        echo "You must start herdr to use hdlm."
        return 1
    end

    set -l ai $argv[1]
    set -l ai2 $argv[2]
    set -l base_dir $PWD
    set -l first true

    herdr workspace rename "$HERDR_WORKSPACE_ID" (basename $base_dir) >/dev/null

    for dir in $base_dir/*/
        test -d $dir; or continue
        set -l dirpath (string replace -r '/$' '' $dir)

        set -l hdl_command (string escape -- hdl $ai)
        test -n "$ai2"; and set hdl_command "$hdl_command "(string escape -- $ai2)

        if test "$first" = true
            herdr pane run "$HERDR_PANE_ID" "cd "(string escape -- $dirpath)" && $hdl_command" >/dev/null
            set first false
        else
            set -l pane_id (herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$dirpath" --no-focus | jq -r '.result.root_pane.pane_id')
            herdr pane run "$pane_id" "$hdl_command" >/dev/null
        end
    end
end

function hsl --description 'сетка панелей, в каждой одна и та же команда'
    if test -z "$argv[1]" -o -z "$argv[2]"
        echo "Usage: hsl <pane_count> <command>"
        return 1
    end
    if test -z "$HERDR_PANE_ID"
        echo "You must start herdr to use hsl."
        return 1
    end

    set -l count $argv[1]
    set -l cmd $argv[2]
    set -l current_dir $PWD

    herdr tab rename "$HERDR_TAB_ID" (basename $current_dir) >/dev/null

    # ceil(sqrt(count)) колонок
    set -l cols 1
    while test (math "$cols * $cols") -lt $count
        set cols (math $cols + 1)
    end

    set -l columns $HERDR_PANE_ID
    for k in (seq 1 (math $cols - 1))
        set -a columns (_herdr_split $columns[-1] right (_herdr_ratio 1 (math "$cols - $k + 1")) $current_dir)
    end

    set -l panes
    for index in (seq 0 (math $cols - 1))
        set -l col $columns[(math $index + 1)]
        set -l rows (math -s0 "$count / $cols")
        test $index -lt (math "$count % $cols"); and set rows (math $rows + 1)

        set -a panes $col
        set -l last $col
        for j in (seq 1 (math $rows - 1))
            set last (_herdr_split $last down (_herdr_ratio 1 (math "$rows - $j + 1")) $current_dir)
            set -a panes $last
        end
    end

    for pane in $panes
        herdr pane run "$pane" "$cmd" >/dev/null
    end
end
