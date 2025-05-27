-- LSP keymaps
return {
  {
    "neovim/nvim-lspconfig",
    opts = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- change a keymap
      -- keys[#keys + 1] = { "K", false }
      keys[#keys + 1] = { "<leader>ck", "<cmd>lua vim.lsp.buf.hover()<CR>", desc = "Hover" }
      keys[#keys + 1] = {
        "<leader>ci",
        function()
          LazyVim.lsp.execute({
            command = "typescript.organizeImports",
            arguments = { vim.api.nvim_buf_get_name(0) },
            title = "Organize Imports",
          })
        end,
        desc = "Organize Imports",
      }
    end,
  },
}
