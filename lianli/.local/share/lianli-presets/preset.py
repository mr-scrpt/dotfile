#!/usr/bin/env python3
"""Lian Li lighting/LCD presets, launched from the Omarchy app menu.

Commands:
  light-off  - all RGB off (fans, pump ring, strimer, rings, mobo, RAM, GPU);
               LCD screens keep working
  light-on   - restore RGB (cyan + white runway everywhere)
  lcd-off    - blank all LCD screens (fan screens + 8.8"); lighting untouched
  lcd-on     - restore LCD screens from backup
"""
import json
import os
import socket
import subprocess
import sys
import time

CYAN = (0, 215, 255)
SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"),
                    "lianli-daemon.sock")
BACKUP = os.path.expanduser("~/.config/lianli/presets/lcds-backup.json")


def ipc(method, params=None, timeout=8.0):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(SOCK)
    req = {"method": method}
    if params is not None:
        req["params"] = params
    s.sendall((json.dumps(req) + "\n").encode())
    s.shutdown(socket.SHUT_WR)
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    s.close()
    return json.loads(buf.decode())


def openrgb_all(mode, color=None):
    """Set every device on the local OpenRGB SDK server (mobo/RAM/GPU/ARGB)."""
    try:
        from openrgb import OpenRGBClient
        from openrgb.utils import RGBColor
    except ImportError:
        print("openrgb-python not available", file=sys.stderr)
        return
    try:
        cli = OpenRGBClient("127.0.0.1", 6742, name="lianli-preset")
    except Exception as e:
        print(f"openrgb connect failed: {e}", file=sys.stderr)
        return
    for d in cli.devices:
        try:
            names = [m.name.lower() for m in d.modes]
            if mode.lower() in names:
                d.set_mode(d.modes[names.index(mode.lower())])
            if color is not None:
                d.set_color(RGBColor(*color))
        except Exception as e:
            print(f"openrgb {d.name}: {e}", file=sys.stderr)


def notify(msg):
    subprocess.run(["notify-send", "-a", "Lian Li", "Lian Li", msg], check=False)


def light_off():
    subprocess.run(["systemctl", "--user", "stop", "rgb-runway.service"], check=False)
    caps = ipc("GetRgbCapabilities").get("data") or []
    off = {"mode": "Off", "colors": [[0, 0, 0]], "speed": 2, "brightness": 4}
    black = {"mode": "Static", "colors": [[0, 0, 0]], "speed": 2, "brightness": 4}
    for c in caps:
        for z in range(len(c.get("zones") or [])):
            r = ipc("SetRgbEffect", {"device_id": c["device_id"], "zone": z, "effect": off})
            if r.get("status") != "ok":
                ipc("SetRgbEffect", {"device_id": c["device_id"], "zone": z, "effect": black})
    openrgb_all("Off")
    openrgb_all("Direct", (0, 0, 0))
    notify("Подсветка выключена (экраны работают)")


def light_on():
    cfg = ipc("GetConfig").get("data") or {}
    rgb = cfg.get("rgb") or {}
    # Re-send each stored effect explicitly: SetRgbConfig with an unchanged
    # config is a hardware no-op for some devices (e.g. Strimer).
    for d in rgb.get("devices") or []:
        for z in d.get("zones") or []:
            ipc("SetRgbEffect", {"device_id": d["device_id"],
                                 "zone": z["zone_index"],
                                 "effect": z["effect"]})
    openrgb_all("Static", CYAN)
    subprocess.run(["systemctl", "--user", "restart", "rgb-runway.service"], check=False)
    notify("Подсветка включена")


def _is_blank(entry):
    return entry.get("type") == "color" and entry.get("rgb") in ([0, 0, 0], None)


def lcd_off():
    cfg = ipc("GetConfig").get("data") or {}
    lcds = cfg.get("lcds") or []
    if not lcds:
        notify("Нет настроенных LCD")
        return
    if not all(_is_blank(e) for e in lcds):
        os.makedirs(os.path.dirname(BACKUP), exist_ok=True)
        with open(BACKUP, "w") as f:
            json.dump(lcds, f, indent=1)
    cfg["lcds"] = [{
        "serial": e.get("serial"),
        "type": "color",
        "rgb": [0, 0, 0],
        "orientation": e.get("orientation", 0.0),
        "fps": 5.0,
    } for e in lcds]
    r = ipc("SetConfig", {"config": cfg})
    notify("Экраны погашены" if r.get("status") == "ok" else f"Ошибка: {r.get('data')}")


def lcd_on():
    if not os.path.exists(BACKUP):
        notify("Бэкап настроек LCD не найден")
        return
    with open(BACKUP) as f:
        lcds = json.load(f)
    cfg = ipc("GetConfig").get("data") or {}
    cfg["lcds"] = lcds
    r = ipc("SetConfig", {"config": cfg})
    notify("Экраны включены" if r.get("status") == "ok" else f"Ошибка: {r.get('data')}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    # wait for the daemon socket (in case invoked right after login)
    for _ in range(15):
        if os.path.exists(SOCK):
            break
        time.sleep(1)
    {"light-off": light_off,
     "light-on": light_on,
     "lcd-off": lcd_off,
     "lcd-on": lcd_on}[cmd]()


if __name__ == "__main__":
    main()
