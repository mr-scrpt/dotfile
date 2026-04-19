#!/bin/sh
# CPU usage % based on /proc/stat deltas. Keeps prev state in /tmp.
STATE=/tmp/lianli_cpu_state
read -r CPU _ USER NICE SYSTEM IDLE IOWAIT IRQ SOFTIRQ STEAL _ < /proc/stat
TOTAL=$((USER + NICE + SYSTEM + IDLE + IOWAIT + IRQ + SOFTIRQ + STEAL))
BUSY=$((USER + NICE + SYSTEM + IRQ + SOFTIRQ + STEAL))
if [ -f "$STATE" ]; then
    read -r PREV_TOTAL PREV_BUSY < "$STATE"
    DT=$((TOTAL - PREV_TOTAL))
    DB=$((BUSY - PREV_BUSY))
    if [ "$DT" -gt 0 ]; then
        echo "$TOTAL $BUSY" > "$STATE"
        echo "$((DB * 100 / DT))"
        exit 0
    fi
fi
echo "$TOTAL $BUSY" > "$STATE"
echo "0"
