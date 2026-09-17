#!/bin/sh
# CPU usage % based on /proc/stat deltas. Keeps prev state in /tmp.
# Guarantees a sampling window (re-samples if too little time has passed).
STATE=/tmp/lianli_cpu_state

read_stat() {
    read -r _ U N S I IO IR SI ST _ < /proc/stat
    T=$((U + N + S + I + IO + IR + SI + ST))
    B=$((U + N + S + IR + SI + ST))
}

read_stat
TOTAL=$T
BUSY=$B

if [ -f "$STATE" ]; then
    read -r PREV_TOTAL PREV_BUSY < "$STATE"
    DT=$((TOTAL - PREV_TOTAL))
    DB=$((BUSY - PREV_BUSY))
    # If too little time has elapsed, take a short sample ourselves
    if [ "$DT" -lt 20 ]; then
        PREV_TOTAL=$TOTAL
        PREV_BUSY=$BUSY
        sleep 0.2
        read_stat
        TOTAL=$T
        BUSY=$B
        DT=$((TOTAL - PREV_TOTAL))
        DB=$((BUSY - PREV_BUSY))
    fi
    if [ "$DT" -gt 0 ]; then
        echo "$TOTAL $BUSY" > "$STATE"
        echo "$((DB * 100 / DT))"
        exit 0
    fi
fi

# First call ever: sample a short window
sleep 0.2
read_stat
DT=$((T - TOTAL))
DB=$((B - BUSY))
echo "$T $B" > "$STATE"
if [ "$DT" -gt 0 ]; then
    echo "$((DB * 100 / DT))"
else
    echo "0"
fi
