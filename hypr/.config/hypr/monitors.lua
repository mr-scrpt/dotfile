-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Small monitor (HDMI-A-1, 2560x1440 @ 1.6 = 1600x900 logical) is always on.
-- Big monitor (DP-1, AORUS FO48U 3840x2160 @ 1 = 3840x2160 logical) is OFF by
-- default and toggled from the bar widget `mr.big-monitor` or with
-- `omarchy-big-monitor on|off|toggle`. The flag lives in XDG_RUNTIME_DIR, so
-- every reboot starts with it off.
--
-- Workspaces: with one monitor everything lives on HDMI-A-1; with the big one
-- on, workspaces 1-5 stay on HDMI-A-1 and 6-10 go to DP-1.
local small, big = "HDMI-A-1", "DP-1"

local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
if runtime_dir == nil or runtime_dir == "" then runtime_dir = "/tmp" end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then file:close() return true end
  return false
end

local big_monitor_on = file_exists(runtime_dir .. "/omarchy-big-monitor-enabled")

if big_monitor_on then
  -- Big on top, small below it, centered: (3840 - 1600) / 2 = 1120.
  hl.monitor({ output = big, mode = "preferred", position = "0x0", scale = 1 })
  hl.monitor({ output = small, mode = "preferred", position = "1120x2160", scale = 1.6 })
else
  hl.monitor({ output = big, disabled = true })
  hl.monitor({ output = small, mode = "preferred", position = "0x0", scale = 1.6 })
end

for ws = 1, 10 do
  hl.workspace_rule({ workspace = tostring(ws), monitor = (big_monitor_on and ws > 5) and big or small })
end
