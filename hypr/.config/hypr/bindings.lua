-- Keybindings — the whole set. Omarchy's stock bindings are switched off with
-- `omarchy_default_bindings = false` in ~/.config/hypr/hyprland.lua, so every
-- binding that exists is listed in this file. Design notes: hypr/README.md in
-- the dotfile repo.
--
-- One modifier = one meaning:
--   SUPER          navigate: move focus, switch workspace, point at things
--   SUPER + SHIFT  launch: open an app (or an app-like tool)
--   SUPER + ALT    act on the window: move, close, resize, fullscreen
--   SUPER + CTRL   system state: bar panels (top row), notifications (home row),
--                  bottom widgets (bottom row)
--   SUPER + thumb  menus and system utilities
-- No three-modifier chords: on a home-row-mod keyboard they need three fingers
-- of one hand. The only exception to the table is SUPER + C/V/X.
--
-- Commands are copied from Omarchy's stock bindings (default/hypr/bindings/*),
-- so behaviour matches upstream; "was:" names the stock chord.

-- Warn on a machine where the flag is missing: stock bindings would come back
-- on top of these and collide.
if _G.omarchy_default_bindings ~= false then
  o.exec_on_start(o.notify("Stock Omarchy keybindings are on: set omarchy_default_bindings = false in ~/.config/hypr/hyprland.lua"))
end

-------------------------------------------------------------------------------
-- SUPER — navigation
-------------------------------------------------------------------------------
-- Focus follows hjkl; on the Hallie board holding SPACE turns hjkl into arrows,
-- so letters are the single source of direction.
o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))   -- was: SUPER + LEFT
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))  -- was: SUPER + DOWN
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))  -- was: SUPER + UP
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))  -- was: SUPER + RIGHT

-- Digits are bound by keycode (code:10 = 1 … code:19 = 0) so they work in any
-- keyboard layout. SUPER + ALT + digit carries the window along (you follow it).
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  o.bind("SUPER + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  o.bind("SUPER + ALT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) })) -- was: SUPER + SHIFT + digit
end

o.bind("SUPER + mouse_down", "Scroll active workspace forward", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + mouse_up", "Scroll active workspace backward", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- Click with the keyboard (like `f` in Vimium): wl-kbptr labels the clickable
-- elements of the active window; typing a label clicks it. Whole screen when no
-- window is focused.
o.bind("SUPER + F", "Click with the keyboard",
  [[a=$(hyprctl activewindow -j | jq -r 'if .size then "\(.size[0])x\(.size[1])+\(.at[0])+\(.at[1])" else empty end'); wl-kbptr ${a:+-r "$a"} -o modes=floating,click -o mode_floating.source=detect]])

-- Omarchy's shared drawer: peek into it here, put a window in with SUPER+ALT+S.
o.bind("SUPER + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))

-- The exception: universal copy / paste / cut are too frequent to take two
-- modifiers. Omarchy's own module is loaded as is (it sends Ctrl+Insert /
-- Shift+Insert to terminals and Ctrl+C/V/X elsewhere); its clipboard-manager
-- chord is dropped here and rebound under SUPER + SHIFT + V.
require("default.hypr.bindings.clipboard")
hl.unbind("SUPER + CTRL + V")

-------------------------------------------------------------------------------
-- SUPER + thumb keys — menus (left thumb) and system utilities (right thumb)
-------------------------------------------------------------------------------
o.bind("SUPER + ESCAPE", "System menu", "omarchy-menu toggle system")
o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle")
o.bind("SUPER + TAB", "Apps menu", "omarchy-menu toggle apps")                 -- was: SUPER + ALT + SPACE
o.bind("XF86PowerOff", "Power menu", "omarchy-menu toggle system", { locked = true })

o.bind("SUPER + RETURN", "Screenshot", "omarchy-capture-screenshot")            -- was: PRINT
o.bind("SUPER + BACKSPACE", "Activity", { tui = "btop" })                       -- was: SUPER + CTRL + T
o.bind("SUPER + DELETE", "Disk usage", "omarchy-launch-tui dua i")

-------------------------------------------------------------------------------
-- SUPER + SHIFT — launch
-------------------------------------------------------------------------------
o.bind("SUPER + SHIFT + RETURN", "Terminal", { omarchy = "terminal" })          -- was: SUPER + RETURN
o.bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + SHIFT + T", "Telegram", { launch = "Telegram", focus = "org.telegram.desktop" })
o.bind("SUPER + SHIFT + H", "Herdr", { omarchy = "terminal-herdr" })            -- was: SUPER + CTRL + RETURN
o.bind("SUPER + SHIFT + D", "Docker", { tui = "omarchy-launch-docker-tui" })
o.bind("SUPER + SHIFT + W", "Google Docs", { webapp = "https://docs.google.com/document/" })
o.bind("SUPER + SHIFT + S", "Station Files", { webapp = "http://192.168.1.100:30051/" })
o.bind("SUPER + SHIFT + R", "Station Torrent", { webapp = "http://192.168.1.100:30024/" })

-- AI agents are apps too.
o.bind("SUPER + SHIFT + A", "Agent", "omarchy-agent --pick")                    -- was: SUPER + SHIFT + CTRL + A
o.bind("SUPER + SHIFT + L", "Agent (local LLM)", "hermes-local-launch")         -- was: SUPER + SHIFT + CTRL + L

-- Tools that put something on the clipboard, bottom-left row X C V.
o.bind("SUPER + SHIFT + X", "Extract text (OCR) from screenshot", "omarchy-capture-text")         -- was: SUPER + CTRL + PRINT
o.bind("SUPER + SHIFT + C", "Color picker", "pkill hyprpicker || hyprpicker -a")                   -- was: SUPER + PRINT
o.bind("SUPER + SHIFT + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")   -- was: SUPER + CTRL + V

-------------------------------------------------------------------------------
-- SUPER + ALT — act on the window (digits: see the workspace loop above)
-------------------------------------------------------------------------------
o.bind("SUPER + ALT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))  -- was: SUPER + SHIFT + LEFT
o.bind("SUPER + ALT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))          -- was: SUPER + SHIFT + DOWN
o.bind("SUPER + ALT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))            -- was: SUPER + SHIFT + UP
o.bind("SUPER + ALT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))  -- was: SUPER + SHIFT + RIGHT

o.bind("SUPER + ALT + Q", "Close window", hl.dsp.window.close())                                -- was: SUPER + W
o.bind("SUPER + ALT + M", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))     -- was: SUPER + F
o.bind("SUPER + ALT + T", "Tiled full screen", "omarchy-hyprland-window-tiled-fullscreen-toggle") -- was: SUPER + CTRL + F
o.bind("SUPER + ALT + F", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" })) -- was: SUPER + T
o.bind("SUPER + ALT + P", "Pop window out (float & pin)", "omarchy-hyprland-window-pop")        -- was: SUPER + O
o.bind("SUPER + ALT + S", "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Scrolling layout: width presets live in looknfeel.lua (explicit_column_widths).
o.bind("SUPER + ALT + R", "Cycle column width preset", hl.dsp.layout("colresize +conf"))
o.bind("SUPER + ALT + E", "Expand column to free space", hl.dsp.layout("fit expand"))
o.bind("SUPER + ALT + W", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle") -- was: SUPER + L

-------------------------------------------------------------------------------
-- SUPER + CTRL — system state. The keyboard rows map to screen areas:
--   top row     = the bar at the top          (panels)
--   home row    = notifications, over windows (left: what will come, right: what came)
--   bottom row  = widgets sliding in from the bottom edge
-------------------------------------------------------------------------------
-- Top row: bar panels in bar order (right hand), calendar and weather (left).
o.bind("SUPER + CTRL + Y", "Agents", "omarchy-shell shell toggle omarchy.agents")
o.bind("SUPER + CTRL + U", "Bluetooth", "omarchy-shell shell toggle omarchy.bluetooth")  -- was: SUPER + CTRL + B
o.bind("SUPER + CTRL + I", "Network", "omarchy-shell shell toggle omarchy.network")      -- was: SUPER + CTRL + W
o.bind("SUPER + CTRL + O", "Audio", "omarchy-shell shell toggle omarchy.audio")          -- was: SUPER + CTRL + A
o.bind("SUPER + CTRL + P", "Display", "omarchy-shell shell toggle omarchy.monitor")      -- was: SUPER + CTRL + D
o.bind("SUPER + CTRL + Q", "Calendar", "omarchy-shell shell toggle omarchy.clock")       -- was: SUPER + CTRL + ALT + D
o.bind("SUPER + CTRL + W", "Toggle weather", "omarchy-notification-weather")             -- was: SUPER + CTRL + ALT + W

-- Home row, right hand: notifications that already arrived.
o.bind("SUPER + CTRL + H", "Open notification history", "omarchy-shell notifications showHistory")  -- was: SUPER + SHIFT + ALT + comma
o.bind("SUPER + CTRL + J", "Dismiss last notification", "omarchy-shell notifications dismissOne")   -- was: SUPER + comma
o.bind("SUPER + CTRL + K", "Dismiss all notifications", "omarchy-shell notifications dismissAll")   -- was: SUPER + SHIFT + comma
o.bind("SUPER + CTRL + L", "Invoke last notification", "omarchy-shell notifications invokeLast")    -- was: SUPER + ALT + comma
o.bind_toggle("SUPER + CTRL + apostrophe", "Toggle silencing notifications", "notification-silencing") -- was: SUPER + CTRL + comma

-- Home row, left hand: what will come (reminders) and the clock.
o.bind("SUPER + CTRL + F", "Set reminder", "omarchy-menu toggle reminder-set")  -- was: SUPER + CTRL + R
o.bind("SUPER + CTRL + D", "Show reminders", "omarchy-reminder show")           -- was: SUPER + CTRL + ALT + R
o.bind("SUPER + CTRL + S", "Show time", "omarchy-notification-time")            -- was: SUPER + CTRL + ALT + T
o.bind("SUPER + CTRL + A", "Clear reminders", "omarchy-reminder clear")         -- was: SUPER + SHIFT + CTRL + R

-- Bottom row: bottom widgets (pyprland scratchpads, ~/.config/pypr/config.toml).
-- Free for more: M , . / and Z X C V B.
o.bind("SUPER + CTRL + N", "Bottom widget: yazi", "pypr-client toggle yazi")

-------------------------------------------------------------------------------
-- Outside SUPER — typing and media keys
-------------------------------------------------------------------------------
o.bind("CTRL + SPACE", "Switch keyboard layout", "hyprctl switchxkblayout all next")

o.bind("XF86AudioRaiseVolume", "Volume up", "omarchy-audio-output-volume raise", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "omarchy-audio-output-volume lower", { locked = true, repeating = true })
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "omarchy-audio-output-volume +1", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "omarchy-audio-output-volume -1", { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", "omarchy-audio-output-volume mute-toggle", { locked = true })
o.bind("XF86AudioMicMute", "Mute microphone", "omarchy-audio-input-mute", { locked = true })
o.bind("SHIFT + XF86AudioMute", "Switch audio output", "omarchy-audio-output-switch", { locked = true })

o.bind("XF86AudioPlay", "Play", "omarchy-shell media playPause", { locked = true })
o.bind("XF86AudioPause", "Pause", "omarchy-shell media playPause", { locked = true })
o.bind("XF86AudioNext", "Next track", "omarchy-shell media next", { locked = true })
o.bind("XF86AudioPrev", "Previous track", "omarchy-shell media previous", { locked = true })
o.bind("ALT + XF86AudioPlay", "Next track", "omarchy-shell media next", { locked = true })
o.bind("ALT + SHIFT + XF86AudioPlay", "Previous track", "omarchy-shell media previous", { locked = true })
o.bind("SHIFT + XF86AudioPlay", "Switch media source", "omarchy-audio-source-switch", { locked = true })
o.bind("SHIFT + XF86AudioPause", "Switch media source", "omarchy-audio-source-switch", { locked = true })
