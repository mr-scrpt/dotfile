return {
  "coder/claudecode.nvim",
  opts = {
    terminal_cmd = "claude --dangerously-skip-permissions",
    diff_opts = {
      open_in_new_tab = true,
      hide_terminal_in_new_tab = true,
    },
    terminal = {
      provider = "snacks",
      snacks_win_opts = {
        position = "float",
        width = 0.85,
        height = 0.85,
        border = "rounded",
        keys = {
          claude_hide = {
            "<leader>ac",
            function(self)
              self:hide()
            end,
            mode = "t",
            desc = "Hide Claude",
          },
        },
      },
    },
  },
}
