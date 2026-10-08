-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- Switch: Ctrl+Space (see bindings.lua)
-- Ukrainian is added on demand by `omarchy-ua-layout` (menu: Trigger → Toggle →
-- Ukrainian Layout): it sets a flag in XDG_RUNTIME_DIR and reloads Hyprland, and
-- this file appends "ua" while the flag exists. Gone again after a reboot.
local ua_flag = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omarchy-ua-layout-enabled")
if ua_flag then ua_flag:close() end

hl.config({
  input = {
    kb_layout = ua_flag and "us,ru,ua" or "us,ru",

    -- Change speed of keyboard repeat.
    repeat_rate = 40,
    repeat_delay = 250,

    -- Start with numlock on by default.
    numlock_by_default = true,

    -- Increase sensitivity for mouse/trackpad (default: 0).
    sensitivity = 0.35,

    -- Turn off mouse acceleration (default: adaptive).
    accel_profile = "flat",

    touchpad = {
      -- Use natural (inverse) scrolling.
      natural_scroll = true,

      -- Use two-finger clicks for right-click instead of lower-right corner.
      clickfinger_behavior = true,

      -- Control the speed of your scrolling.
      scroll_factor = 0.4,

      -- Enable the touchpad while typing.
      disable_while_typing = false,

      -- Left-click-and-drag with three fingers.
      drag_3fg = 1,
    },
  },
})
