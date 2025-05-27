local adapters_config = require("codecompanion.adapters_config")
local adapters_setup = require("codecompanion.adapters_setup")

-- Основная конфигурация плагина
return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "ravitemer/codecompanion-history.nvim",
    {
      "ravitemer/mcphub.nvim", -- Manage MCP servers
      cmd = "MCPHub",
      build = "npm install -g mcp-hub@latest",
      config = true,
    },
  },
  opts = {
    adapters = adapters_setup.setup_adapters(adapters_config),
    strategies = {
      chat = {
        adapter = adapters_config.active.chat,
        tools = {
          groups = {
            ["full_stack_dev"] = {
              description = "Full Stack Developer - Can run code, edit code and modify files",
              system_prompt = "**DO NOT** make any assumptions about the dependencies that a user has installed. If you need to install any dependencies to fulfil the user's request, do so via the Command Runner tool. If the user doesn't specify a path, use their current working directory.",
              tools = {
                "cmd_runner",
                "editor",
                "files",
              },
            },
          },
          ["cmd_runner"] = {
            callback = "strategies.chat.agents.tools.cmd_runner",
            description = "Run shell commands initiated by the LLM",
            opts = {
              requires_approval = true,
            },
          },
          ["editor"] = {
            callback = "strategies.chat.agents.tools.editor",
            description = "Update a buffer with the LLM's response",
          },
          ["files"] = {
            callback = "strategies.chat.agents.tools.files",
            description = "Update the file system with the LLM's response",
            opts = {
              requires_approval = true,
            },
          },
          opts = {
            auto_submit_errors = false, -- Send any errors to the LLM automatically?
            auto_submit_success = false, -- Send any successful output to the LLM automatically?
          },
        },
        variables = {
          ["buffer"] = {
            callback = "strategies.chat.variables.buffer",
            description = "Share the current buffer with the LLM",
            opts = {
              contains_code = true,
              has_params = true,
            },
          },
          ["lsp"] = {
            callback = "strategies.chat.variables.lsp",
            description = "Share LSP information and code for the current buffer",
            opts = {
              contains_code = true,
            },
          },
          ["viewport"] = {
            callback = "strategies.chat.variables.viewport",
            description = "Share the code that you see in Neovim with the LLM",
            opts = {
              contains_code = true,
            },
          },
        },
        slash_commands = {
          ["buffer"] = {
            callback = "strategies.chat.slash_commands.buffer",
            description = "Insert open buffers",
            opts = {
              contains_code = true,
              provider = "snacks",
            },
          },
          ["fetch"] = {
            callback = "strategies.chat.slash_commands.fetch",
            description = "Insert URL contents",
          },
          ["file"] = {
            callback = "strategies.chat.slash_commands.file",
            description = "Insert a file",
            opts = {
              contains_code = true,
              max_lines = 1000,
              provider = "snacks",
            },
          },
          ["help"] = {
            callback = "strategies.chat.slash_commands.help",
            description = "Insert content from help tags",
            opts = {
              contains_code = false,
              max_lines = 128, -- Maximum amount of lines to of the help file to send (NOTE: Each vimdoc line is typically 10 tokens)
              provider = "snacks",
            },
          },
          ["now"] = {
            callback = "strategies.chat.slash_commands.now",
            description = "Insert the current date and time",
            opts = {
              contains_code = false,
            },
          },
          ["symbols"] = {
            callback = "strategies.chat.slash_commands.symbols",
            description = "Insert symbols for a selected file",
            opts = {
              contains_code = true,
              provider = "snacks",
            },
          },
          ["terminal"] = {
            callback = "strategies.chat.slash_commands.terminal",
            description = "Insert terminal output",
            opts = {
              contains_code = false,
            },
          },
          ["workspace"] = {
            callback = "strategies.chat.slash_commands.workspace",
            description = "Load a workspace file",
            opts = {
              contains_code = true,
            },
          },
        },
      },
      inline = {
        adapter = adapters_config.active.inline,
      },
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
      history = {
        enabled = true,
        opts = {
          -- Keymap to open history from chat buffer (default: gh)
          keymap = "gh",
          -- Automatically generate titles for new chats
          auto_generate_title = true,
          ---On exiting and entering neovim, loads the last chat on opening chat
          continue_last_chat = false,
          ---When chat is cleared with `gx` delete the chat from history
          delete_on_clearing_chat = false,
          -- Picker interface ("telescope", "snacks" or "default")
          picker = "snacks",
          ---Enable detailed logging for history extension
          enable_logging = false,
          ---Directory path to save the chats
          dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
          -- Save all chats by default
          auto_save = true,
          -- Keymap to save the current chat manually
          save_chat_keymap = "sc",
          -- Number of days after which chats are automatically deleted (0 to disable)
          expiration_days = 0,
        },
      },
    },
    opts = {
      log_level = "DEBUG",
    },

    display = {
      chat = {
        show_header_separator = true,
        show_settings = true,
        icons = {
          pinned_buffer = " ",
          watched_buffer = "👀 ",
        },
        window = {
          layout = "buffer", -- float|vertical|horizontal|buffer
          border = "single",
          height = 0.8,
          width = 0.45,
          relative = "editor",
          full_height = true, -- when set to false, vsplit will be used to open the chat buffer vs. botright/topleft vsplit
          opts = {
            breakindent = true,
            cursorcolumn = false,
            cursorline = false,
            foldcolumn = "0",
            linebreak = true,
            list = false,
            numberwidth = 1,
            signcolumn = "no",
            spell = false,
            wrap = true,
          },
        },
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
      "<Leader>at",
      "<cmd>CodeCompanionChat Toggle<CR>",
      desc = "[A]i [T]oggle codecompanion for a chat buffer",
      mode = { "n", "v" },
    },
    {
      "<LocalLeader>aa",
      "<cmd>CodeCompanionChat Add<CR>",
      desc = "[A]i [A]dd codecompanion for a chat buffer",
      mode = { "v" },
    },
  },
  init = function()
    vim.cmd([[cab cc CodeCompanion]])
  end,
}
-- return {}
-- return {
--   "olimorris/codecompanion.nvim",
--   dependencies = {
--     "nvim-lua/plenary.nvim",
--     "nvim-treesitter/nvim-treesitter",
--     "ravitemer/codecompanion-history.nvim",
--     {
--       "ravitemer/mcphub.nvim", -- Manage MCP servers
--       cmd = "MCPHub",
--       build = "npm install -g mcp-hub@latest",
--       config = true,
--     },
--   },
--   opts = {
--     adapters = {
--       gemma3 = function()
--         return require("codecompanion.adapters").extend("openai_compatible", {
--           name = "lm_studio",
--           opts = {
--             stream = true,
--           },
--           env = {
--             api_key = "EMPTY", -- LM Studio doesn't require an actual API key
--             url = "http://localhost:1234", -- Your local LM Studio endpoint
--           },
--           schema = {
--             model = {
--               default = "gemma-3-27b-it-qat",
--             },
--           },
--         })
--       end,
--       qwen3_30b = function()
--         return require("codecompanion.adapters").extend("openai_compatible", {
--           name = "qwen3-30b(MOE)",
--           opts = {
--             stream = true,
--           },
--           env = {
--             api_key = "qwen3-30b-a3b", -- LM Studio doesn't require an actual API key
--             url = "http://localhost:1234", -- Your local LM Studio endpoint
--           },
--           schema = {
--             model = {
--               -- default = "qwen3-30b-a3b",
--               default = "qwen3-30b-a3b@q6_k",
--             },
--           },
--         })
--       end,
--       qwen3 = function()
--         return require("codecompanion.adapters").extend("openai_compatible", {
--           name = "qwen3-14b",
--           opts = {
--             stream = true,
--           },
--           env = {
--             api_key = "qwen3-14b", -- LM Studio doesn't require an actual API key
--             url = "http://localhost:1234", -- Your local LM Studio endpoint
--           },
--           schema = {
--             model = {
--               default = "qwen3-14b",
--             },
--           },
--         })
--       end,
--       ollama = function()
--         return require("codecompanion.adapters").extend("ollama", {
--           name = "llama3.2:1b",
--           opts = {
--             stream = true,
--           },
--           schema = {
--             model = {
--               default = "llama3.2:1b",
--             },
--           },
--         })
--       end,
--     },
--     extensions = {
--       mcphub = {
--         callback = "mcphub.extensions.codecompanion",
--         opts = {
--           make_vars = true,
--           make_slash_commands = true,
--           show_result_in_chat = true,
--         },
--       },
--       history = {
--         enabled = true,
--         opts = {
--           -- Keymap to open history from chat buffer (default: gh)
--           keymap = "gh",
--           -- Automatically generate titles for new chats
--           auto_generate_title = true,
--           ---On exiting and entering neovim, loads the last chat on opening chat
--           continue_last_chat = false,
--           ---When chat is cleared with `gx` delete the chat from history
--           delete_on_clearing_chat = false,
--           -- Picker interface ("telescope", "snacks" or "default")
--           picker = "snacks",
--           ---Enable detailed logging for history extension
--           enable_logging = false,
--           ---Directory path to save the chats
--           dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
--           -- Save all chats by default
--           auto_save = true,
--           -- Keymap to save the current chat manually
--           save_chat_keymap = "sc",
--           -- Number of days after which chats are automatically deleted (0 to disable)
--           expiration_days = 0,
--         },
--       },
--     },
--     opts = {
--       log_level = "DEBUG",
--     },
--     strategies = {
--       chat = {
--         -- adapter = "qwen3", -- Use the openai adapter we configured above
--         adapter = "qwen3_30b", -- Use the openai adapter we configured above
--         -- adapter = "qwen3-30b-a3b@q6_k",
--         tools = {
--           groups = {
--             ["full_stack_dev"] = {
--               description = "Full Stack Developer - Can run code, edit code and modify files",
--               system_prompt = "**DO NOT** make any assumptions about the dependencies that a user has installed. If you need to install any dependencies to fulfil the user's request, do so via the Command Runner tool. If the user doesn't specify a path, use their current working directory.",
--               tools = {
--                 "cmd_runner",
--                 "editor",
--                 "files",
--               },
--             },
--           },
--           ["cmd_runner"] = {
--             callback = "strategies.chat.agents.tools.cmd_runner",
--             description = "Run shell commands initiated by the LLM",
--             opts = {
--               requires_approval = true,
--             },
--           },
--           ["editor"] = {
--             callback = "strategies.chat.agents.tools.editor",
--             description = "Update a buffer with the LLM's response",
--           },
--           ["files"] = {
--             callback = "strategies.chat.agents.tools.files",
--             description = "Update the file system with the LLM's response",
--             opts = {
--               requires_approval = true,
--             },
--           },
--           opts = {
--             auto_submit_errors = false, -- Send any errors to the LLM automatically?
--             auto_submit_success = false, -- Send any successful output to the LLM automatically?
--           },
--         },
--         variables = {
--           ["buffer"] = {
--             callback = "strategies.chat.variables.buffer",
--             description = "Share the current buffer with the LLM",
--             opts = {
--               contains_code = true,
--               has_params = true,
--             },
--           },
--           ["lsp"] = {
--             callback = "strategies.chat.variables.lsp",
--             description = "Share LSP information and code for the current buffer",
--             opts = {
--               contains_code = true,
--             },
--           },
--           ["viewport"] = {
--             callback = "strategies.chat.variables.viewport",
--             description = "Share the code that you see in Neovim with the LLM",
--             opts = {
--               contains_code = true,
--             },
--           },
--         },
--         slash_commands = {
--           ["buffer"] = {
--             callback = "strategies.chat.slash_commands.buffer",
--             description = "Insert open buffers",
--             opts = {
--               contains_code = true,
--               -- provider = default_providers.pick_provider, -- default|telescope|mini_pick|fzf_lua|snacks
--               provider = "snacks",
--             },
--           },
--           ["fetch"] = {
--             callback = "strategies.chat.slash_commands.fetch",
--             description = "Insert URL contents",
--             -- opts = {
--             --   adapter = "jina",
--             -- },
--           },
--           ["file"] = {
--             callback = "strategies.chat.slash_commands.file",
--             description = "Insert a file",
--             opts = {
--               contains_code = true,
--               max_lines = 1000,
--               -- provider = default_providers.pick_provider, -- default|telescope|mini_pick|fzf_lua|snacks
--               provider = "snacks",
--             },
--           },
--           ["help"] = {
--             callback = "strategies.chat.slash_commands.help",
--             description = "Insert content from help tags",
--             opts = {
--               contains_code = false,
--               max_lines = 128, -- Maximum amount of lines to of the help file to send (NOTE: Each vimdoc line is typically 10 tokens)
--               -- provider = default_providers.help_provider, -- telescope|mini_pick|fzf_lua|snacks
--               provider = "snacks",
--             },
--           },
--           ["now"] = {
--             callback = "strategies.chat.slash_commands.now",
--             description = "Insert the current date and time",
--             opts = {
--               contains_code = false,
--             },
--           },
--           ["symbols"] = {
--             callback = "strategies.chat.slash_commands.symbols",
--             description = "Insert symbols for a selected file",
--             opts = {
--               contains_code = true,
--               -- provider = default_providers.pick_provider, -- default|telescope|mini_pick|fzf_lua|snacks
--               provider = "snacks",
--             },
--           },
--           ["terminal"] = {
--             callback = "strategies.chat.slash_commands.terminal",
--             description = "Insert terminal output",
--             opts = {
--               contains_code = false,
--             },
--           },
--           ["workspace"] = {
--             callback = "strategies.chat.slash_commands.workspace",
--             description = "Load a workspace file",
--             opts = {
--               contains_code = true,
--             },
--           },
--         },
--       },
--       inline = {
--
--         adapter = "qwen3_30b",
--         -- adapter = "",
--       }, -- Also use the openai adapter for inline completions
--     },
--     display = {
--       chat = {
--         show_header_separator = true,
--         show_settings = true,
--         icons = {
--           pinned_buffer = " ",
--           watched_buffer = "👀 ",
--         },
--         window = {
--           layout = "buffer", -- float|vertical|horizontal|buffer
--           -- position = nil, -- left|right|top|bottom (nil will default depending on vim.opt.plitright|vim.opt.splitbelow)
--           border = "single",
--           height = 0.8,
--           width = 0.45,
--           relative = "editor",
--           full_height = true, -- when set to false, vsplit will be used to open the chat buffer vs. botright/topleft vsplit
--           opts = {
--             breakindent = true,
--             cursorcolumn = false,
--             cursorline = false,
--             foldcolumn = "0",
--             linebreak = true,
--             list = false,
--             numberwidth = 1,
--             signcolumn = "no",
--             spell = false,
--             wrap = true,
--           },
--         },
--       },
--     },
--   },
--   keys = {
--     {
--       "<C-a>",
--       "<cmd>CodeCompanionActions<CR>",
--       desc = "Open the action palette",
--       mode = { "n", "v" },
--     },
--     {
--       "<Leader>a",
--       "<cmd>CodeCompanionChat Toggle<CR>",
--       desc = "Toggle a chat buffer",
--       mode = { "n", "v" },
--     },
--     {
--       "<LocalLeader>a",
--       "<cmd>CodeCompanionChat Add<CR>",
--       desc = "Add code to a chat buffer",
--       mode = { "v" },
--     },
--   },
--   init = function()
--     vim.cmd([[cab cc CodeCompanion]])
--   end,
-- }
