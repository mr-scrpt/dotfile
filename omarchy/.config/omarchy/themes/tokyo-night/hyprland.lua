local active_border_color = "#7aa2f7"
local inactive_border_color = "rgba(595959aa)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})

-- Terminal transparency (active / inactive). Overrides Omarchy's default 0.985 / 0.96.
o.window({ tag = "terminal" }, { opacity = "0.96 0.94" })
