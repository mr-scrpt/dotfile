#!/bin/sh
# Unified RGB profile switcher for all hardware on this machine.
#
# Ownership split:
#   Lian Li daemon (USB UniHub + wireless)   -> 8.8" LED Ring, 5 fan LCD/RGB groups
#   OpenRGB (SMBus + HID)                    -> DDR5 ENE DRAM ×2, ASUS mobo + ARGB headers, Strimer cable
#   BIOS/L-Connect firmware (do not touch)   -> WaterBlock2 AIO pump LCD + ring
#
# Usage:
#   rgb_profile.sh main      # cyan (#00D7FF)
#   rgb_profile.sh white     # warm white (#FFF5EB)
#   rgb_profile.sh apply     # re-apply the last profile (used at boot)
#
# The "apply" mode is what systemd calls after boot — it skips the lianli-daemon
# restart (config is already on disk from last switch) and only re-pushes
# OpenRGB colours, which never persist across the openrgb server restart.

set -e

STATE_FILE="/home/mr/.config/lianli/current_rgb_profile"
CFG="/home/mr/.config/lianli/config.json"
OPENRGB_PORT=6742

MODE="${1:-}"
case "$MODE" in
    main|white)
        PROFILE="$MODE"
        ;;
    apply)
        PROFILE="$(cat "$STATE_FILE" 2>/dev/null || echo main)"
        ;;
    *)
        echo "Usage: $0 <main|white|apply>" >&2
        exit 1
        ;;
esac

case "$PROFILE" in
    main)
        # Target cyan #00D7FF (identical value for both lianli and OpenRGB).
        LIANLI_COLORS='[[0, 215, 255]]'
        OPENRGB_HEX=00D7FF
        ;;
    white)
        # Cool-white LEDs skew blue — nudge green/blue down for a neutral look.
        LIANLI_COLORS='[[255, 245, 235]]'
        OPENRGB_HEX=FFF5EB
        ;;
esac

# ---- Lian Li side (only on explicit main/white switch) ----

if [ "$MODE" != "apply" ]; then
    python3 - "$CFG" "$LIANLI_COLORS" <<'PY'
import json, sys, os
cfg_path, colors_json = sys.argv[1:3]
colors = json.loads(colors_json)

# All RGB devices the lianli daemon owns, with their zone counts.
# Source: "lianli-daemon::rgb_controller: RGB controller: 1 wired device(s), 3 wireless device(s)"
# — update if hardware changes.
DEVICES = [
    {"device_id": "hid:0416:8050:1-9.3.3", "zones": 1},       # wired 8.8" LED Ring (60 LEDs)
    {"device_id": "wireless:1f:51:87:e5:66:e1", "zones": 3},  # Slv3Lcd 3-fan group
    {"device_id": "wireless:9f:f0:76:e5:66:e1", "zones": 2},  # Slv3Lcd 2-fan group
    # WaterBlock2 AIO pump intentionally omitted — leave firmware animation alone.
]

def build_effect():
    return {
        "brightness": 4,
        "colors": colors,
        "direction": "Clockwise",
        "mode": "Static",
        "scope": "All",
        "speed": 2,
    }

def build_device(d):
    return {
        "device_id": d["device_id"],
        "mb_rgb_sync": False,
        "zones": [
            {"effect": build_effect(), "swap_lr": False, "swap_tb": False, "zone_index": i}
            for i in range(d["zones"])
        ],
    }

with open(cfg_path) as f:
    cfg = json.load(f)

cfg.setdefault('rgb', {})
cfg['rgb']['enabled'] = True
cfg['rgb']['devices'] = [build_device(d) for d in DEVICES]

tmp = cfg_path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(cfg, f, indent=2)
os.replace(tmp, cfg_path)
PY

    systemctl --user restart lianli-daemon
    echo "$PROFILE" > "$STATE_FILE"
fi

# ---- OpenRGB side (every time — state lives in server RAM only) ----
#
# Device layout (`openrgb --list-devices`):
#   0: ENE DRAM (0x71)    -> Static
#   1: ENE DRAM (0x73)    -> Static
#   2: Lian Li Strimer    -> Direct (LED-strip class needs Direct)
#   3: ASUS mobo + ARGB   -> Static (paints onboard + every connected header fan)

openrgb_apply() {
    openrgb --client "127.0.0.1:${OPENRGB_PORT}" -d "$1" -m "$2" -c "$3" >/dev/null 2>&1 || {
        echo "OpenRGB --client failed on device $1 mode $2 (server not ready?)" >&2
        return 1
    }
}

openrgb_apply 0 Static "$OPENRGB_HEX"
openrgb_apply 1 Static "$OPENRGB_HEX"
openrgb_apply 2 Direct "$OPENRGB_HEX"
openrgb_apply 3 Static "$OPENRGB_HEX"

echo "RGB profile set to: $PROFILE"
