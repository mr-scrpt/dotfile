-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Big monitor (DP-1, AORUS FO48U) is OFF by default and toggled from the bar
-- widget `mr.big-monitor` or with `omarchy-big-monitor on|off|toggle`.
-- The flag lives in XDG_RUNTIME_DIR, so every reboot starts with it off.
local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
if runtime_dir == nil or runtime_dir == "" then runtime_dir = "/tmp" end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then file:close() return true end
  return false
end

local big_monitor_on = file_exists(runtime_dir .. "/omarchy-big-monitor-enabled")

if big_monitor_on then
  -- Big monitor (3840x2160 @ scale 2 = 1920x1080 logical) on top,
  -- small one (2560x1440 @ scale 2 = 1280x720 logical) below it, centered.
  hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
  hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "320x1080", scale = omarchy_monitor_scale })
else
  hl.monitor({ output = "DP-1", disabled = true })
  hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
end

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
