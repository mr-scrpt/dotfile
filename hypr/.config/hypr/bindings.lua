-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- TG Videos: local web UI for saving videos from Telegram chats (~/Work/tg-videos).
o.bind("SUPER + SHIFT + CTRL + V", "TG Videos", "tg-videos open")

-- Скретчпад: плавающее окно с nvim (файл на каждый день в ~/Notes/scratch/).
o.bind("SUPER + N", "Scratchpad", os.getenv("HOME") .. "/.local/bin/scratchpad")

-- Правило окна для скретчпада: плавающее, по центру, крупное.
o.window({ class = "^scratchpad$" }, {
  float = true,
  size = { 1000, 550 },
  center = true,
})

-- Пауэр-меню (System) по Super+Alt+Escape — как на прошлой системе.
o.bind("SUPER + ALT + ESCAPE", "Power menu", "omarchy-menu toggle system")

-- Закрытие окна: Super+Shift+Q вместо дефолтного Super+W.
hl.unbind("SUPER + W")
o.bind("SUPER + SHIFT + Q", "Close window", hl.dsp.window.close())

