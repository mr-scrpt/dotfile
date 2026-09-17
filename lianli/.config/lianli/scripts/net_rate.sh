#!/bin/sh
# Stateless-to-us caller: compute KB/s using cached state in /tmp between calls.
IFACE="${1:-wlan0}"
RX=$(cat "/sys/class/net/$IFACE/statistics/rx_bytes" 2>/dev/null || echo 0)
TX=$(cat "/sys/class/net/$IFACE/statistics/tx_bytes" 2>/dev/null || echo 0)
NOW_NS=$(date +%s%N)
STATE="/tmp/lianli_net_${IFACE}.state"
if [ -f "$STATE" ]; then
    read -r PREV_BYTES PREV_NS < "$STATE"
    DELTA_BYTES=$(( RX + TX - PREV_BYTES ))
    DELTA_NS=$(( NOW_NS - PREV_NS ))
    if [ "$DELTA_NS" -gt 100000000 ]; then
        # bytes / (ns/1e9) / 1024 = KB/s
        RATE=$(( DELTA_BYTES * 1000000 / (DELTA_NS / 1000) / 1024 ))
        echo "$((RX + TX)) $NOW_NS" > "$STATE"
        echo "$RATE"
        exit 0
    fi
fi
echo "$((RX + TX)) $NOW_NS" > "$STATE"
echo "0"
