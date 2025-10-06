return {
  "ravitemer/mcphub.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "yetone/avante.nvim",
  },
  build = "npm install -g mcp-hub@latest",
  config = function()
    require("mcphub").setup({
      port = 1771,
      config = vim.fn.expand("~/.config/nvim/mcpservers.json"),
      log = {
        level = vim.log.levels.WARN,
        to_file = true,
      },
      on_ready = function()
        vim.notify("MCP Hub backend server is initialized and ready.", vim.log.levels.INFO)
      end,
      -- Add the Avante extension configuration
      extensions = {
        avante = {
          make_slash_commands = true, -- Enable slash commands for MCP server prompts
        },
      },
      -- Auto approve MCP tool requests to avoid confirmation dialogs
      auto_approve = true,
    })
  end,
}
