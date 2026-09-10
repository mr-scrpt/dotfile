#!/usr/bin/env python3
"""Re-apply all stored Lian Li RGB effects + full reset helper.

apply  - re-send every stored RGB effect from the daemon config to hardware
         (needed at boot: some devices, e.g. Strimer, don't get effects
         pushed by the daemon on startup).
reset  - full recovery: restart lianli-daemon (re-inits fan control, pump,
         LCDs), wait for devices, re-apply RGB everywhere, restart the
         runway streamer and OpenRGB profile.
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


def wait_daemon(tries=60):
    for _ in range(tries):
        if os.path.exists(SOCK):
            try:
                if ipc("ListDevices").get("status") == "ok":
                    return True
            except Exception:
                pass
        time.sleep(1)
    return False


def apply_rgb():
    """Re-send every stored effect to hardware. Returns (ok, fail)."""
    cfg = ipc("GetConfig").get("data") or {}
    rgb = cfg.get("rgb") or {}
    ok = fail = 0
    for d in rgb.get("devices") or []:
        for z in d.get("zones") or []:
            try:
                r = ipc("SetRgbEffect", {"device_id": d["device_id"],
                                         "zone": z["zone_index"],
                                         "effect": z["effect"]})
                if r.get("status") == "ok":
                    ok += 1
                else:
                    fail += 1
            except Exception:
                fail += 1
    return ok, fail


def openrgb_cyan():
    try:
        from openrgb import OpenRGBClient
        from openrgb.utils import RGBColor
        cli = OpenRGBClient("127.0.0.1", 6742, name="lianli-apply")
        for d in cli.devices:
            try:
                names = [m.name.lower() for m in d.modes]
                if "static" in names:
                    d.set_mode(d.modes[names.index("static")])
                d.set_color(RGBColor(*CYAN))
            except Exception:
                pass
    except Exception:
        pass


def notify(msg):
    subprocess.run(["notify-send", "-a", "Lian Li", "Lian Li", msg], check=False)


def cmd_apply():
    if not wait_daemon():
        notify("Демон Lian Li не отвечает")
        sys.exit(1)
    # devices (especially wireless) need time to enumerate after daemon start
    time.sleep(5)
    ok, fail = apply_rgb()
    # keep retrying while the daemon is still bringing devices up (cold boot
    # can take 30-60s before RF/HID writes start succeeding)
    attempt = 0
    while fail and attempt < 10:
        time.sleep(10)
        ok, fail = apply_rgb()
        attempt += 1
    subprocess.run(["systemctl", "--user", "restart", "rgb-runway.service"],
                   check=False)
    print(f"applied: {ok} ok, {fail} fail (retries: {attempt})")


def cmd_reset():
    notify("Сброс: перезапуск демона и переприменение настроек…")
    subprocess.run(["systemctl", "--user", "restart", "lianli-daemon.service"],
                   check=False)
    if not wait_daemon():
        notify("Демон Lian Li не поднялся — смотри journalctl")
        sys.exit(1)
    time.sleep(8)          # let wireless discovery settle
    ok, fail = apply_rgb()
    if fail:
        time.sleep(5)
        apply_rgb()
    subprocess.run(["systemctl", "--user", "restart", "rgb-runway.service"],
                   check=False)
    subprocess.run(["systemctl", "--user", "restart", "openrgb-profile.service"],
                   check=False)
    time.sleep(8)
    openrgb_cyan()
    notify("Сброс завершён: кулеры, помпа, подсветка и экраны переинициализированы")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "apply"
    {"apply": cmd_apply, "reset": cmd_reset}[cmd]()


if __name__ == "__main__":
    main()
