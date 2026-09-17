#!/bin/bash
# Ping 1.1.1.1 and return current latency
# Also maintains a rolling 1-minute average in a temp file

STATS_FILE="/tmp/lianli-ping-stats"
NOW=$(date +%s)

# Get current ping
CURRENT=$(ping -c 1 -W 2 1.1.1.1 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1/')

if [ -z "$CURRENT" ]; then
    CURRENT="0"
fi

# Append to stats file: timestamp value
echo "$NOW $CURRENT" >> "$STATS_FILE"

# Remove entries older than 60 seconds
CUTOFF=$((NOW - 60))
if [ -f "$STATS_FILE" ]; then
    awk -v cutoff="$CUTOFF" '$1 >= cutoff' "$STATS_FILE" > "${STATS_FILE}.tmp"
    mv "${STATS_FILE}.tmp" "$STATS_FILE"
fi

# Calculate average
AVG=$(awk '{ sum += $2; n++ } END { if (n>0) printf "%.1f", sum/n; else print "0" }' "$STATS_FILE")

echo "$CURRENT|$AVG"
