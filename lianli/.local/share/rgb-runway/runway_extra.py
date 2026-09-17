#!/usr/bin/env python3
"""Runway effect streamer for devices that only support Static/Direct.

- Wired LED rings (HydroShift II LCD ring, Universal Screen 8.8" ring):
  streamed via lianli-daemon's unix IPC socket (SetRgbDirect).
- ENE DRAM sticks: streamed via OpenRGB SDK server on 127.0.0.1:6742.
- Wireless Lian Li fans/pump: uploads the Runway frame animation to the
  device firmware (SetRgbFrames) on start and periodically re-uploads,
  since firmware forgets the animation after reconnect/power cycle.

Base color: Lian Li cyan #00D7FF. Runner: white.
"""
import json
import os
import socket
import time

CYAN = (0, 215, 255)
WHITE = (255, 255, 255)
TICK = 0.30          # seconds per animation step (wired rings / DRAM)
REUPLOAD_S = 120     # re-upload wireless firmware animation every 2 min
WIRELESS_INTERVAL_MS = 250  # firmware frame interval (higher = slower)
RING_STEP = 1        # LEDs the runner advances per frame (1 = smoothest)

SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"),
                    "lianli-daemon.sock")

# device_id -> (total_leds, ring_size)
WIRED_RINGS = {
    "hid:5a23c13deac4c205w": (24, 24),      # HydroShift II LCD RGB Ring
    "hid:0416:8050:6-9.3.3": (60, 60),      # Universal Screen 8.8" LED Ring
}
WIRELESS = {
    "wireless:8b:06:ef:e5:66:e1": (24, 24),   # HydroShift II pump head
    "wireless:9f:f0:76:e5:66:e1": (80, 40),   # UNI FAN SL V3 x2
    "wireless:1f:51:87:e5:66:e1": (120, 40),  # UNI FAN SL V3 x3
}


def ipc(method, params=None, timeout=5.0):
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


def ring_frame(total, ring, pos, runner):
    frame = []
    n = max(total // ring, 1)
    for _ in range(n):
        for i in range(ring):
            d = (i - pos) % ring
            frame.append(list(WHITE) if d < runner else list(CYAN))
    return frame


def upload_wireless():
    ok = True
    for dev_id, (total, ring) in WIRELESS.items():
        frames = [ring_frame(total, ring, p, 4)
                  for p in range(0, ring, RING_STEP)]
        try:
            r = ipc("SetRgbFrames",
                    {"device_id": dev_id, "frames": frames,
                     "interval_ms": WIRELESS_INTERVAL_MS})
            status = r.get("status")
            print(f"wireless upload {dev_id}: {status}", flush=True)
            if status != "ok":
                ok = False
        except Exception as e:
            print(f"wireless upload {dev_id} failed: {e}", flush=True)
            ok = False
    return ok


def connect_openrgb():
    try:
        from openrgb import OpenRGBClient
        from openrgb.utils import RGBColor, DeviceType
        cli = OpenRGBClient("127.0.0.1", 6742, name="runway-extra", protocol_version=3)
        drams = [d for d in cli.devices if d.type == DeviceType.DRAM]
        for d in drams:
            direct = next((m for m in d.modes if m.name.lower() == "direct"), None)
            if direct:
                d.set_mode(direct)
        print(f"openrgb: {len(drams)} DRAM device(s)", flush=True)
        return cli, drams, RGBColor
    except Exception as e:
        print(f"openrgb connect failed: {e}", flush=True)
        return None, [], None


def main():
    # wait for lianli-daemon socket
    for _ in range(60):
        if os.path.exists(SOCK):
            break
        time.sleep(1)

    upload_wireless()
    last_upload = time.time()

    cli, drams, RGBColor = connect_openrgb()
    last_openrgb_try = time.time()

    pos = 0
    while True:
        t0 = time.time()

        # wired rings via lianli IPC
        for dev_id, (total, ring) in WIRED_RINGS.items():
            frame = ring_frame(total, ring, pos % ring, 4)
            try:
                ipc("SetRgbDirect", {"device_id": dev_id, "zone": 0, "colors": frame})
            except Exception:
                pass  # daemon restarting; retried next tick

        # DRAM white spot (8 LEDs): runner of 2 on cyan
        if drams and RGBColor:
            for d in drams:
                n = len(d.leds)
                colors = []
                for i in range(n):
                    dd = (i - (pos % n)) % n
                    colors.append(RGBColor(*WHITE) if dd < 2 else RGBColor(*CYAN))
                try:
                    d.set_colors(colors, fast=True)
                except Exception:
                    drams = []
        elif time.time() - last_openrgb_try > 30:
            cli, drams, RGBColor = connect_openrgb()
            last_openrgb_try = time.time()

        if time.time() - last_upload > REUPLOAD_S:
            upload_wireless()
            last_upload = time.time()

        pos += 1
        dt = time.time() - t0
        time.sleep(max(0.0, TICK - dt))


if __name__ == "__main__":
    main()
