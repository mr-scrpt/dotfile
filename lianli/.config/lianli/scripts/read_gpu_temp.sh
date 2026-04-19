#!/bin/sh
awk '{printf "%.0f", $1/1000}' /sys/class/hwmon/hwmon2/temp1_input
