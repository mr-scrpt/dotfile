-- Markdown rendered in the buffer: headings, tables, code blocks, callouts.
-- Cursor line and insert mode stay raw. <leader>um toggles rendering.
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  opts = {
    code = { sign = false, width = "block", right_pad = 1 },
    heading = { sign = false },
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)
    Snacks.toggle({
      name = "Render Markdown",
      get = require("render-markdown").get,
      set = require("render-markdown").set,
    }):map("<leader>um")
  end,
}
