-- Favorites source for neo-tree (own plugin mr-scrpt/neo-tree-fav).
-- F in the filesystem tree toggles a favorite (⭐ after the name),
-- <leader>F opens the favorites float. Lists are per project (cwd) and live
-- in stdpath("state")/neo-tree-fav, outside the config dir.
local dir = vim.fn.stdpath("state") .. "/neo-tree-fav"

-- default neo-tree renderers + favorite_indicator after the name
local function with_indicator(extra)
  local content = {
    { "name", zindex = 10 },
    { "favorite_indicator", zindex = 10 },
    { "symlink_target", zindex = 10, highlight = "NeoTreeSymbolicLinkTarget" },
    { "clipboard", zindex = 10 },
  }
  vim.list_extend(content, extra)
  vim.list_extend(content, {
    { "file_size", zindex = 10, align = "right" },
    { "type", zindex = 10, align = "right" },
    { "last_modified", zindex = 10, align = "right" },
    { "created", zindex = 10, align = "right" },
  })
  return content
end

return {
  {
    "mr-scrpt/neo-tree-fav",
    lazy = true, -- loaded as a neo-tree dependency
    opts = {
      keymap = false, -- bound below as a lazy key, so neo-tree loads on demand
      storage_dir = dir,
      log_file = dir .. "/neo-tree-fav.log",
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = { "mr-scrpt/neo-tree-fav" },
    keys = {
      { "<leader>F", "<cmd>Neotree float favorites<cr>", desc = "Favorites (NeoTree float)" },
    },
    opts = {
      sources = { "filesystem", "buffers", "git_status", "neo-tree-fav" },
      source_selector = {
        winbar = true,
        content_layout = "center",
        sources = {
          { source = "filesystem" },
          { source = "buffers" },
          { source = "git_status" },
          { source = "favorites" },
        },
      },
      filesystem = {
        renderers = {
          directory = {
            { "indent" },
            { "icon" },
            { "current_filter" },
            {
              "container",
              content = with_indicator({
                { "diagnostics", errors_only = true, zindex = 20, align = "right", hide_when_expanded = true },
                { "git_status", zindex = 10, align = "right", hide_when_expanded = true },
              }),
            },
          },
          file = {
            { "indent" },
            { "icon" },
            {
              "container",
              content = with_indicator({
                { "bufnr", zindex = 10 },
                { "modified", zindex = 20, align = "right" },
                { "diagnostics", zindex = 20, align = "right" },
                { "git_status", zindex = 10, align = "right" },
              }),
            },
          },
        },
      },
    },
  },
}
