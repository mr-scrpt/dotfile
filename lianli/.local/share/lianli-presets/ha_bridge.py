#!/usr/bin/env python3
"""MQTT bridge: expose the Lian Li rig to Home Assistant (→ HomeKit).

Publishes MQTT-discovery entities under one device "Station PC":
  switch.station_pc_lighting   -> preset.py light-on / light-off
  switch.station_pc_displays   -> preset.py lcd-on / lcd-off
  button.station_pc_rgb_reset  -> apply_rgb.py reset
  sensor cpu/gpu temp (from lianli-sensor-service cache, if present)

State is derived from the daemon config (no separate state file):
  lighting = rgb-runway.service active
  displays = any LCD entry is not a black colour frame
Credentials: ~/.local/share/secrets/mqtt.cred (key=value: host, port, user, password).
"""
import json
import os
import subprocess
import sys
import threading
import time

import paho.mqtt.client as mqtt

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import preset  # noqa: E402

PY = sys.executable
CRED = os.path.expanduser("~/.local/share/secrets/mqtt.cred")
SENSOR_DIR = "/tmp/lianli-sensors"
NODE = "station_pc"
BASE = f"lianli/{NODE}"
AVAIL = f"{BASE}/availability"
DEVICE = {"identifiers": [NODE], "name": "Station PC", "manufacturer": "Lian Li",
          "model": "lianli-linux rig", "sw_version": "ha_bridge 1"}

ENTITIES = {
    "lighting": {"component": "switch", "name": "Lighting", "icon": "mdi:led-strip-variant"},
    "displays": {"component": "switch", "name": "Displays", "icon": "mdi:monitor-small"},
    "rgb_reset": {"component": "button", "name": "RGB Reset", "icon": "mdi:restart"},
    "cpu_temp": {"component": "sensor", "name": "CPU Temperature", "unit": "°C",
                 "device_class": "temperature", "file": "cpu_temp"},
    "gpu_temp": {"component": "sensor", "name": "GPU Temperature", "unit": "°C",
                 "device_class": "temperature", "file": "gpu_temp"},
}


def load_cred():
    d = {}
    with open(CRED) as f:
        for line in f:
            if "=" in line:
                k, v = line.strip().split("=", 1)
                d[k] = v
    return d


def run(*args):
    subprocess.run(list(args), check=False, timeout=180)


def lighting_state():
    r = subprocess.run(["systemctl", "--user", "is-active", "-q", "rgb-runway.service"])
    return r.returncode == 0


def displays_state():
    try:
        cfg = preset.ipc("GetConfig").get("data") or {}
    except Exception:
        return None
    lcds = cfg.get("lcds") or []
    return bool(lcds) and not all(preset._is_blank(e) for e in lcds)


def read_sensor(name):
    try:
        with open(os.path.join(SENSOR_DIR, name)) as f:
            return round(float(f.read().strip()), 1)
    except Exception:
        return None


class Bridge:
    def __init__(self):
        c = load_cred()
        self.cli = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="lianli-bridge")
        self.cli.username_pw_set(c["user"], c["password"])
        self.cli.will_set(AVAIL, "offline", retain=True)
        self.cli.on_connect = self.on_connect
        self.cli.on_message = self.on_message
        self.host, self.port = c.get("host", "127.0.0.1"), int(c.get("port", 1883))
        self.lock = threading.Lock()

    # --- discovery -------------------------------------------------------
    def announce(self):
        for key, e in ENTITIES.items():
            uid = f"{NODE}_{key}"
            comp = e["component"]
            payload = {"name": e["name"], "unique_id": uid,
                       "default_entity_id": f"{comp}.{uid}",
                       "device": DEVICE, "availability_topic": AVAIL}
            if "icon" in e:
                payload["icon"] = e["icon"]
            if comp == "switch":
                payload.update(command_topic=f"{BASE}/{key}/set",
                               state_topic=f"{BASE}/{key}/state",
                               payload_on="ON", payload_off="OFF")
            elif comp == "button":
                payload.update(command_topic=f"{BASE}/{key}/press", payload_press="PRESS")
            elif comp == "sensor":
                payload.update(state_topic=f"{BASE}/{key}/state",
                               unit_of_measurement=e["unit"], device_class=e["device_class"],
                               state_class="measurement", expire_after=120)
            self.cli.publish(f"homeassistant/{comp}/{uid}/config", json.dumps(payload), retain=True)

    # --- state -----------------------------------------------------------
    def publish_states(self):
        l = lighting_state()
        self.cli.publish(f"{BASE}/lighting/state", "ON" if l else "OFF", retain=True)
        d = displays_state()
        if d is not None:
            self.cli.publish(f"{BASE}/displays/state", "ON" if d else "OFF", retain=True)
        for key, e in ENTITIES.items():
            if e["component"] == "sensor":
                v = read_sensor(e["file"])
                if v is not None:
                    self.cli.publish(f"{BASE}/{key}/state", str(v))
        self.cli.publish(AVAIL, "online", retain=True)

    # --- callbacks -------------------------------------------------------
    def on_connect(self, cli, userdata, flags, reason, props=None):
        cli.subscribe(f"{BASE}/+/set")
        cli.subscribe(f"{BASE}/+/press")
        self.announce()
        self.publish_states()

    def on_message(self, cli, userdata, msg):
        key = msg.topic.split("/")[-2]
        val = msg.payload.decode().strip().upper()
        threading.Thread(target=self.handle, args=(key, val), daemon=True).start()

    def handle(self, key, val):
        with self.lock:
            if key == "lighting":
                run(PY, os.path.join(HERE, "preset.py"), "light-on" if val == "ON" else "light-off")
            elif key == "displays":
                run(PY, os.path.join(HERE, "preset.py"), "lcd-on" if val == "ON" else "lcd-off")
            elif key == "rgb_reset":
                run(PY, os.path.join(HERE, "apply_rgb.py"), "reset")
            time.sleep(1)
            self.publish_states()

    def loop(self):
        self.cli.connect_async(self.host, self.port, keepalive=60)
        self.cli.loop_start()
        while True:
            time.sleep(15)
            if self.cli.is_connected():
                self.publish_states()


if __name__ == "__main__":
    Bridge().loop()
