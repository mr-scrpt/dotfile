//! Continuously samples a fixed set of system sensors, interpolates their
//! values toward their latest target at a configurable rate, and publishes the
//! interpolated values as small plain-text files under /tmp/lianli-sensors/.
//! Templates read these files with `cat` for cheap smooth-animated display.

use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
    thread,
    time::{Duration, Instant},
};

const OUT_DIR: &str = "/tmp/lianli-sensors";
const TICK: Duration = Duration::from_millis(16); // 60 Hz interpolation loop
const TARGET_REFRESH: Duration = Duration::from_millis(500); // 2 Hz raw sensor reads

// Per-sensor max change per second — governs how fast the displayed value
// chases the true sensor value. Higher = more responsive, lower = smoother.
const MAX_CPU_LOAD_PER_SEC: f64 = 80.0;
const MAX_GPU_LOAD_PER_SEC: f64 = 80.0;
const MAX_CPU_TEMP_PER_SEC: f64 = 12.0;
const MAX_GPU_TEMP_PER_SEC: f64 = 12.0;
const MAX_MEM_USED_PER_SEC: f64 = 2.0;
const MAX_MEM_PCT_PER_SEC: f64 = 40.0;
const MAX_NET_RATE_PER_SEC: f64 = 4000.0; // KB/s

// Hardware paths (Arch-local). Adjust if hwmon indices change.
const HWMON_CPU_TEMP: &str = "/sys/class/hwmon/hwmon3/temp1_input";
const HWMON_GPU_TEMP: &str = "/sys/class/hwmon/hwmon2/temp1_input";
const AMD_GPU_BUSY: &str = "/sys/class/drm/card1/device/gpu_busy_percent";
const NET_IFACE: &str = "wlan0";

fn read_str(path: &str) -> Option<String> {
    fs::read_to_string(path).ok()
}

fn read_f64(path: &str) -> Option<f64> {
    read_str(path)?.trim().parse().ok()
}

fn read_hwmon_deg(path: &str) -> Option<f64> {
    read_f64(path).map(|v| v / 1000.0)
}

fn read_cpu_stat() -> Option<(u64, u64)> {
    let s = read_str("/proc/stat")?;
    let line = s.lines().next()?;
    let nums: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        .take(8)
        .filter_map(|s| s.parse().ok())
        .collect();
    if nums.len() < 8 {
        return None;
    }
    let total: u64 = nums.iter().sum();
    // user + nice + system + irq + softirq + steal — excludes idle & iowait
    let busy = nums[0] + nums[1] + nums[2] + nums[5] + nums[6] + nums[7];
    Some((total, busy))
}

fn read_mem() -> Option<(f64, f64)> {
    // Returns (used_gb, used_pct)
    let s = read_str("/proc/meminfo")?;
    let mut total = 0f64;
    let mut avail = 0f64;
    for line in s.lines() {
        let mut parts = line.split_whitespace();
        let key = parts.next()?;
        let val: f64 = parts.next()?.parse().ok()?;
        match key {
            "MemTotal:" => total = val,
            "MemAvailable:" => avail = val,
            _ => {}
        }
    }
    if total <= 0.0 {
        return None;
    }
    Some(((total - avail) / 1024.0 / 1024.0, (total - avail) * 100.0 / total))
}

fn read_net_bytes(iface: &str) -> Option<u64> {
    let rx = read_f64(&format!("/sys/class/net/{}/statistics/rx_bytes", iface))? as u64;
    let tx = read_f64(&format!("/sys/class/net/{}/statistics/tx_bytes", iface))? as u64;
    Some(rx.saturating_add(tx))
}

struct Sensor {
    name: &'static str,
    current: f64,
    target: f64,
    max_per_sec: f64,
    decimals: u8,
}

impl Sensor {
    fn new(name: &'static str, max_per_sec: f64, decimals: u8) -> Self {
        Self {
            name,
            current: 0.0,
            target: 0.0,
            max_per_sec,
            decimals,
        }
    }

    fn tick(&mut self, dt_sec: f64) {
        let diff = self.target - self.current;
        let max_step = self.max_per_sec * dt_sec;
        let step = if diff.abs() <= max_step {
            diff
        } else {
            max_step * diff.signum()
        };
        self.current += step;
    }

    fn format(&self) -> String {
        match self.decimals {
            0 => format!("{}", self.current.round() as i64),
            _ => format!("{:.*}", self.decimals as usize, self.current),
        }
    }
}

fn write_atomic(dir: &Path, name: &str, payload: &str) {
    let tmp_path: PathBuf = dir.join(format!(".{}.tmp", name));
    let final_path: PathBuf = dir.join(name);
    if let Ok(mut f) = fs::File::create(&tmp_path) {
        let _ = writeln!(f, "{}", payload);
        drop(f);
        let _ = fs::rename(&tmp_path, &final_path);
    }
}

fn main() {
    let out_dir = Path::new(OUT_DIR);
    fs::create_dir_all(out_dir).expect("create OUT_DIR");

    let mut cpu_load = Sensor::new("cpu_load", MAX_CPU_LOAD_PER_SEC, 0);
    let mut cpu_temp = Sensor::new("cpu_temp", MAX_CPU_TEMP_PER_SEC, 0);
    let mut gpu_load = Sensor::new("gpu_load", MAX_GPU_LOAD_PER_SEC, 0);
    let mut gpu_temp = Sensor::new("gpu_temp", MAX_GPU_TEMP_PER_SEC, 0);
    let mut mem_used = Sensor::new("mem_used", MAX_MEM_USED_PER_SEC, 1);
    let mut mem_pct = Sensor::new("mem_pct", MAX_MEM_PCT_PER_SEC, 0);
    let mut net_rate = Sensor::new("net_rate", MAX_NET_RATE_PER_SEC, 0);

    // State for delta-based sensors
    let mut prev_cpu: Option<(u64, u64)> = None;
    let mut prev_net: Option<(u64, Instant)> = None;

    // Prime sensors with sensible initial targets so interpolation starts meaningfully
    if let Some((v, p)) = read_mem() {
        mem_used.target = v;
        mem_used.current = v;
        mem_pct.target = p;
        mem_pct.current = p;
    }
    if let Some(v) = read_hwmon_deg(HWMON_CPU_TEMP) {
        cpu_temp.target = v;
        cpu_temp.current = v;
    }
    if let Some(v) = read_hwmon_deg(HWMON_GPU_TEMP) {
        gpu_temp.target = v;
        gpu_temp.current = v;
    }
    if let Some(v) = read_f64(AMD_GPU_BUSY) {
        gpu_load.target = v;
        gpu_load.current = v;
    }

    let mut last_target = Instant::now()
        .checked_sub(TARGET_REFRESH)
        .unwrap_or_else(Instant::now);

    loop {
        let now = Instant::now();

        // -- Refresh targets every TARGET_REFRESH --
        if now.duration_since(last_target) >= TARGET_REFRESH {
            last_target = now;

            if let Some((t, b)) = read_cpu_stat() {
                if let Some((pt, pb)) = prev_cpu {
                    let dt = t.saturating_sub(pt);
                    let db = b.saturating_sub(pb);
                    if dt > 0 {
                        let pct = (db as f64) * 100.0 / (dt as f64);
                        cpu_load.target = pct.clamp(0.0, 100.0);
                    }
                }
                prev_cpu = Some((t, b));
            }

            if let Some(v) = read_hwmon_deg(HWMON_CPU_TEMP) {
                cpu_temp.target = v;
            }
            if let Some(v) = read_hwmon_deg(HWMON_GPU_TEMP) {
                gpu_temp.target = v;
            }
            if let Some(v) = read_f64(AMD_GPU_BUSY) {
                gpu_load.target = v.clamp(0.0, 100.0);
            }
            if let Some((v, p)) = read_mem() {
                mem_used.target = v;
                mem_pct.target = p;
            }
            if let Some(bytes) = read_net_bytes(NET_IFACE) {
                if let Some((pb, pt)) = prev_net {
                    let dt_sec = (now - pt).as_secs_f64();
                    if dt_sec > 0.05 {
                        let rate_kb_sec = bytes.saturating_sub(pb) as f64 / dt_sec / 1024.0;
                        net_rate.target = rate_kb_sec.max(0.0);
                    }
                }
                prev_net = Some((bytes, now));
            }
        }

        // -- Interpolate and publish --
        let dt_sec = TICK.as_secs_f64();
        for s in [
            &mut cpu_load,
            &mut cpu_temp,
            &mut gpu_load,
            &mut gpu_temp,
            &mut mem_used,
            &mut mem_pct,
            &mut net_rate,
        ] {
            s.tick(dt_sec);
            write_atomic(out_dir, s.name, &s.format());
        }

        let spent = now.elapsed();
        if spent < TICK {
            thread::sleep(TICK - spent);
        }
    }
}
