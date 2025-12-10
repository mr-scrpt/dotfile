#!/usr/bin/env bash

# Fish shell reloads configuration automatically on new instances.
# For existing instances, there is no standard way to force a reload from outside.
notify-send -h string:x-canonical-private-synchronous:sys-notify "Fish Shell" "New instances will use updated config."
