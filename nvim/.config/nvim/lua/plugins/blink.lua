return {
  "saghen/blink.cmp",
  opts_extend = {
    "sources.compat",
    "sources.default",
  },
  opts = {
    keymap = {
      preset = "enter",
      ["<A-Space>"] = { "show" },
    },
    completion = {
      menu = {
        border = "rounded",
        winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
      },
      documentation = {
        window = {
          border = "rounded",
        },
      },
    },
  },
}
