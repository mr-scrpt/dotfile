#!/bin/sh
# Usage: smooth_sensor.sh <key> <target_ttl_sec> <step_per_call> <cmd...>
# Returns a value that walks toward the command's output in small steps,
# so the caller (gauge widget) sees a smooth transition instead of discrete jumps.
KEY="$1"
TTL="$2"
STEP="$3"
shift 3
TARGET_CACHE="/tmp/lianli_smooth_${KEY}_target"
STATE="/tmp/lianli_smooth_${KEY}"

NOW=$(date +%s)
TARGET=""
if [ -f "$TARGET_CACHE" ]; then
    AGE=$(( NOW - $(stat -c %Y "$TARGET_CACHE" 2>/dev/null || echo 0) ))
    [ "$AGE" -lt "$TTL" ] && TARGET=$(cat "$TARGET_CACHE")
fi
if [ -z "$TARGET" ]; then
    TARGET=$("$@" 2>/dev/null)
    [ -z "$TARGET" ] && [ -f "$TARGET_CACHE" ] && TARGET=$(cat "$TARGET_CACHE")
    [ -z "$TARGET" ] && TARGET=0
    echo "$TARGET" > "$TARGET_CACHE"
fi

if [ -f "$STATE" ]; then
    CUR=$(cat "$STATE")
else
    CUR=$TARGET
fi

NEW=$(awk -v c="$CUR" -v t="$TARGET" -v s="$STEP" '
BEGIN {
    d = t - c
    if (d > s) d = s
    else if (d < -s) d = -s
    v = c + d
    printf "%.1f", v
}')
echo "$NEW" > "$STATE"
echo "$NEW"
