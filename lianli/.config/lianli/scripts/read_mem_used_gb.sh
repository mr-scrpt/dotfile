#!/bin/sh
# Used memory in GB (1 decimal)
awk '/MemTotal:/ {tot=$2} /MemAvailable:/ {avail=$2} END {printf "%.1f", (tot-avail)/1024/1024}' /proc/meminfo
