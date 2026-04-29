//! Continuously samples a fixed set of system sensors, interpolates their
//! values toward their latest target at a configurable rate, and publishes the
//! interpolated values as small plain-text files under /tmp/lianli-sensors/.
//! Templates read these files with `cat` for cheap smooth-animated display.

use std::{
    collections::VecDeque,
    fs,
    io::Write,
    path::{Path, PathBuf},
    process::Command,
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
const MAX_NET_RATE_MB_PER_SEC: f64 = 4.0; // MB/s — same slew curve scaled to MB

// Hardware paths (Arch-local). Adjust if hwmon indices change.
const HWMON_CPU_TEMP: &str = "/sys/class/hwmon/hwmon3/temp1_input";
// GPU is now the NVIDIA RTX 5080 (since 2026-04-25). NVIDIA's proprietary
// driver does NOT expose hwmon or `gpu_busy_percent` sysfs files, so we
// shell out to `nvidia-smi` once per TARGET_REFRESH for both load and temp
// in a single fork. The previous AMD card1 paths returned 0 forever.
const NET_IFACE: &str = "wlan0";

// Ping target and cadence. Runs on a dedicated thread so the 60 Hz publish
// loop never blocks on network I/O. One fork per second instead of one per
// render frame — the render loop reads the published file directly.
const PING_TARGET: &str = "1.1.1.1";
const PING_INTERVAL: Duration = Duration::from_secs(1);
const PING_TIMEOUT_SEC: u32 = 2;
const PING_AVG_WINDOW: Duration = Duration::from_secs(60);

fn read_str(path: &str) -> Option<String> {
    fs::read_to_string(path).ok()
}

fn read_f64(path: &str) -> Option<f64> {
    read_str(path)?.trim().parse().ok()
}

fn read_hwmon_deg(path: &str) -> Option<f64> {
    read_f64(path).map(|v| v / 1000.0)
}

/// Single fork to nvidia-smi returning (utilization%, temperature°C) for
/// the primary NVIDIA GPU. Costs ~30ms wall — called at TARGET_REFRESH
/// cadence (2 Hz), so total CPU overhead is negligible.
fn read_nvidia_gpu() -> Option<(f64, f64)> {
    let output = Command::new("nvidia-smi")
        .args([
            "--query-gpu=utilization.gpu,temperature.gpu",
            "--format=csv,noheader,nounits",
        ])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let stdout = String::from_utf8(output.stdout).ok()?;
    let line = stdout.lines().next()?;
    let mut parts = line.split(',').map(|p| p.trim());
    let load: f64 = parts.next()?.parse().ok()?;
    let temp: f64 = parts.next()?.parse().ok()?;
    Some((load.clamp(0.0, 100.0), temp))
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

/// Parses the `time=NN.N ms` field from `ping` output. Returns None on
/// packet loss or malformed output; caller treats that as "keep previous".
fn parse_ping_time_ms(stdout: &str) -> Option<f64> {
    for line in stdout.lines() {
        if let Some(start) = line.find("time=") {
            let rest = &line[start + 5..];
            let end = rest.find(' ').unwrap_or(rest.len());
            if let Ok(v) = rest[..end].parse::<f64>() {
                return Some(v);
            }
        }
    }
    None
}

/// Runs one ICMP probe per `PING_INTERVAL` on a dedicated thread and
/// publishes the latest sample + rolling 60 s average under OUT_DIR.
fn spawn_ping_thread(out_dir: PathBuf) {
    thread::spawn(move || {
        let mut window: VecDeque<(Instant, f64)> = VecDeque::with_capacity(64);

        loop {
            let now = Instant::now();

            let reading = Command::new("ping")
                .args([
                    "-c",
                    "1",
                    "-W",
                    &PING_TIMEOUT_SEC.to_string(),
                    "-n", // numeric, skip reverse DNS
                    PING_TARGET,
                ])
                .output()
                .ok()
                .and_then(|out| {
                    if out.status.success() {
                        parse_ping_time_ms(&String::from_utf8_lossy(&out.stdout))
                    } else {
                        None
                    }
                });

            if let Some(ms) = reading {
                window.push_back((now, ms));
                let cutoff = now - PING_AVG_WINDOW;
                while window.front().map_or(false, |&(t, _)| t < cutoff) {
                    window.pop_front();
                }
                let avg = if window.is_empty() {
                    ms
                } else {
                    window.iter().map(|&(_, v)| v).sum::<f64>() / window.len() as f64
                };
                write_atomic(&out_dir, "ping_cur", &format!("{:.1}", ms));
                write_atomic(&out_dir, "ping_avg", &format!("{:.1}", avg));
            }
            // On packet loss we keep the previously published values rather
            // than churning the files — smoother display, no "0 ms" spikes.

            let spent = now.elapsed();
            if spent < PING_INTERVAL {
                thread::sleep(PING_INTERVAL - spent);
            }
        }
    });
}

fn main() {
    let out_dir = Path::new(OUT_DIR);
    fs::create_dir_all(out_dir).expect("create OUT_DIR");

    spawn_ping_thread(out_dir.to_path_buf());

    let mut cpu_load = Sensor::new("cpu_load", MAX_CPU_LOAD_PER_SEC, 0);
    let mut cpu_temp = Sensor::new("cpu_temp", MAX_CPU_TEMP_PER_SEC, 0);
    let mut gpu_load = Sensor::new("gpu_load", MAX_GPU_LOAD_PER_SEC, 0);
    let mut gpu_temp = Sensor::new("gpu_temp", MAX_GPU_TEMP_PER_SEC, 0);
    let mut mem_used = Sensor::new("mem_used", MAX_MEM_USED_PER_SEC, 1);
    let mut mem_pct = Sensor::new("mem_pct", MAX_MEM_PCT_PER_SEC, 0);
    let mut net_rate = Sensor::new("net_rate", MAX_NET_RATE_PER_SEC, 0);
    let mut net_rate_mb = Sensor::new("net_rate_mb", MAX_NET_RATE_MB_PER_SEC, 2);

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
    if let Some((load, temp)) = read_nvidia_gpu() {
        gpu_load.target = load;
        gpu_load.current = load;
        gpu_temp.target = temp;
        gpu_temp.current = temp;
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
            if let Some((load, temp)) = read_nvidia_gpu() {
                gpu_load.target = load;
                gpu_temp.target = temp;
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
                        net_rate_mb.target = (rate_kb_sec / 1024.0).max(0.0);
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
            &mut net_rate_mb,
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
