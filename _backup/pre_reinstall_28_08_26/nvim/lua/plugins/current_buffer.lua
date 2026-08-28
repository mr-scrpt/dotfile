return {
  "mr-scrpt/current_coder.nvim",
  config = function()
    require("current_coder").setup({
      keymaps = {
        copy_to_next = "<leader>oo", -- opposite
        copy_to_left = "<leader>oh",
        copy_to_right = "<leader>ol",
      },
      silent = false,
      create_commands = true,
    })
  end,
}
