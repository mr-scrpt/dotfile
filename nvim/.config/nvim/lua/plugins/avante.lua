return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
  opts = {},
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "echasnovski/mini.pick", -- for file_selector provider mini.pick
    "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    "ibhagwan/fzf-lua", -- for file_selector provider fzf
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua", -- for providers='copilot'
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
        -- openai = {
        -- 	endpoint = "https://api.deepseek.com/v1",
        -- 	model = "deepseek-chat",
        -- 	timeout = 30000, -- Timeout in milliseconds
        -- 	temperature = 0,
        -- 	max_tokens = 4096,
        -- 	-- optional
        -- 	api_key_name = "DEEPSEEK_API_KEY", -- default OPENAI_API_KEY if not set
        -- },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}
-- local prefix = "<Leader>a"
-- return {
--   {
--     "yetone/avante.nvim",
--     event = "VeryLazy",
--     lazy = true,
--     version = false, -- set this if you want to always pull the latest change
--     opts = {
--       -- add any opts here
--       mappings = {
--         ask = prefix .. "<CR>",
--         edit = prefix .. "e",
--         refresh = prefix .. "r",
--         focus = prefix .. "f",
--         toggle = {
--           default = prefix .. "t",
--           debug = prefix .. "d",
--           hint = prefix .. "h",
--           suggestion = prefix .. "s",
--           repomap = prefix .. "R",
--         },
--         diff = {
--           next = "]c",
--           prev = "[c",
--         },
--         files = {
--           add_current = prefix .. ".",
--         },
--       },
--       behaviour = {
--         auto_suggestions = false,
--       },
--       provider = "copilot",
--       copilot = {
--         model = "claude-3.5-sonnet",
--         temperature = 0,
--         max_tokens = 8192,
--       },
--     },
--     -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
--     -- dynamically build it, taken from astronvim
--     build = vim.fn.has("win32") == 1 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
--       or "make",
--     dependencies = {
--       -- "stevearc/dressing.nvim",
--       "nvim-lua/plenary.nvim",
--       "MunifTanjim/nui.nvim",
--       {
--         -- support for image pasting
--         "HakonHarnes/img-clip.nvim",
--         event = "VeryLazy",
--         opts = {
--           -- recommended settings
--           default = {
--             embed_image_as_base64 = false,
--             prompt_for_file_name = false,
--             drag_and_drop = {
--               insert_mode = true,
--             },
--             -- required for Windows users
--             use_absolute_path = true,
--           },
--         },
--       },
--       {
--         -- Make sure to set this up properly if you have lazy=true
--         "MeanderingProgrammer/render-markdown.nvim",
--         dependencies = {
--           -- make sure rendering happens even without opening a markdown file first
--           "yetone/avante.nvim",
--         },
--         opts = function(_, opts)
--           opts.file_types = opts.file_types or { "markdown", "norg", "rmd", "org" }
--           vim.list_extend(opts.file_types, { "Avante" })
--         end,
--       },
--     },
--   },
-- }
