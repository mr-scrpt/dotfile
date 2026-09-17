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

-- Switch keyboard layout (us/ru) on all keyboards.
o.bind("CTRL + SPACE", "Switch keyboard layout", "hyprctl switchxkblayout all next")

-- Local LLM: load Qwen3.8-27B into the GPU (llama.cpp) and open Hermes on the 'local' profile.
o.bind("SUPER + SHIFT + CTRL + L", "Agent (local LLM)", "hermes-local-launch")

-- Scrolling layout controls.
-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- Note: SUPER+comma was "Dismiss last notification" and SUPER+SHIFT+comma was
-- "Dismiss all notifications"; unbound here so the keys can scroll columns.
hl.unbind("SUPER + comma")
hl.unbind("SUPER + SHIFT + comma")
o.bind("SUPER + PERIOD", "Scroll to next column", hl.dsp.layout("move +col"))
o.bind("SUPER + comma", "Scroll to previous column", hl.dsp.layout("move -col"))
o.bind("SUPER + SHIFT + PERIOD", "Swap column right", hl.dsp.layout("swapcol r"))
o.bind("SUPER + SHIFT + comma", "Swap column left", hl.dsp.layout("swapcol l"))
o.bind("SUPER + EQUAL", "Widen current column", hl.dsp.layout("colresize +0.1"))
o.bind("SUPER + MINUS", "Narrow current column", hl.dsp.layout("colresize -0.1"))
