#!/bin/sh
# Usage: cached_sensor.sh <key> <ttl_sec> [<min_delta>] <read-cmd...>
# min_delta: if new read differs by < this from previous value, return old.
#           0 or absent = no hysteresis.
KEY="$1"
TTL="$2"
shift 2
MIN_DELTA=0
case "$1" in
    ''|*[!0-9.]*) ;;  # not a number, treat as command start
    *) MIN_DELTA="$1"; shift ;;
esac
CACHE="/tmp/lianli_cache_${KEY}"
# TTL check
if [ -f "$CACHE" ]; then
    AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt "$TTL" ]; then
        cat "$CACHE"
        exit 0
    fi
fi
NEW=$("$@" 2>/dev/null)
if [ -z "$NEW" ]; then
    [ -f "$CACHE" ] && cat "$CACHE" || echo "0"
    exit 0
fi
# Hysteresis: if diff < MIN_DELTA, keep old
if [ -f "$CACHE" ] && [ "$MIN_DELTA" != "0" ]; then
    OLD=$(cat "$CACHE")
    DIFF=$(awk -v a="$NEW" -v b="$OLD" 'BEGIN{d=a-b; if(d<0)d=-d; print d}')
    CMP=$(awk -v d="$DIFF" -v m="$MIN_DELTA" 'BEGIN{print (d<m)?1:0}')
    if [ "$CMP" = "1" ]; then
        # Keep old value, but update mtime so TTL counts from now
        touch "$CACHE"
        echo "$OLD"
        exit 0
    fi
fi
echo "$NEW" > "$CACHE"
echo "$NEW"
