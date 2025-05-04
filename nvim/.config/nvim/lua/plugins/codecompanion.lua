return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    {
      "ravitemer/mcphub.nvim", -- Manage MCP servers
      cmd = "MCPHub",
      build = "npm install -g mcp-hub@latest",
      config = true,
    },
    -- {
    --   "Davidyz/VectorCode", -- Index and search code in your repositories
    --   version = "*",
    --   build = "pipx upgrade vectorcode",
    --   dependencies = { "nvim-lua/plenary.nvim" },
    -- },
  },
  opts = {
    adapters = {
      -- Configure the OpenAI adapter for your local LM Studio endpoint
      gemma3 = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          name = "lm_studio",
          opts = {
            stream = true,
          },
          env = {
            api_key = "EMPTY", -- LM Studio doesn't require an actual API key
            url = "http://localhost:1234", -- Your local LM Studio endpoint
          },
          schema = {
            model = {
              default = "gemma-3-27b-it-qat",
            },
          },
        })
      end,
      qwen3 = function()
        return require("codecompanion.adapters").extend("openai_compatible", {
          name = "qwen3-14b",
          opts = {
            stream = true,
          },
          env = {
            api_key = "qwen3-14b", -- LM Studio doesn't require an actual API key
            url = "http://localhost:1234", -- Your local LM Studio endpoint
          },
          schema = {
            model = {
              default = "qwen3-14b",
            },
          },
        })
      end,
      ollama = function()
        return require("codecompanion.adapters").extend("ollama", {
          name = "llama3.2:1b",
          opts = {
            stream = true,
          },
          schema = {
            model = {
              default = "llama3.2:1b",
            },
          },
        })
      end,
    },
    extensions = {
      mcphub = {
        callback = "mcphub.extensions.codecompanion",
        opts = {
          make_vars = true,
          make_slash_commands = true,
          show_result_in_chat = true,
        },
      },
    },
    strategies = {
      chat = {
        adapter = "qwen3", -- Use the openai adapter we configured above
        slash_commands = {
          ["buffer"] = {
            opts = {
              keymaps = {
                modes = {
                  i = "<C-b>",
                },
              },
            },
          },
          ["help"] = {
            opts = {
              max_lines = 1000,
            },
          },
        },
        tools = {
          opts = {
            auto_submit_success = false,
            auto_submit_errors = false,
          },
        },
      },
      -- inline = { adapter = "lm_studio" }, -- Also use the openai adapter for inline completions
    },
    display = {
      chat = {
        show_header_separator = true,
        show_settings = true,
      },
    },
  },
  keys = {
    {
      "<C-a>",
      "<cmd>CodeCompanionActions<CR>",
      desc = "Open the action palette",
      mode = { "n", "v" },
    },
    {
      "<Leader>a",
      "<cmd>CodeCompanionChat Toggle<CR>",
      desc = "Toggle a chat buffer",
      mode = { "n", "v" },
    },
    {
      "<LocalLeader>a",
      "<cmd>CodeCompanionChat Add<CR>",
      desc = "Add code to a chat buffer",
      mode = { "v" },
    },
  },
  init = function()
    vim.cmd([[cab cc CodeCompanion]])
  end,
}
