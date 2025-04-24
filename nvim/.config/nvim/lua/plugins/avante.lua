return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false, -- Never set this value to "*"! Never!
  opts = {
    -- Основной провайдер для большинства операций
    provider = "ollama-deepseek-14b",
    -- Специальный провайдер для автоподсказок
    -- auto_suggestions_provider = "ollama-deepseek-coder-v2-24b",
    auto_suggestions_provider = "ollama-qwen-1.5b",

    -- Определяем разные провайдеры
    vendors = {
      ["ollama-deepseek-1.5b"] = {
        __inherited_from = "ollama", -- Наследуем базовую конфигурацию ollama
        model = "deepseek-r1:1.5b",
        endpoint = "http://172.17.0.1:11434/",
        options = {
          num_ctx = 16384,
        },
      },
      ["ollama-deepseek-14b"] = {
        __inherited_from = "ollama", -- Наследуем базовую конфигурацию ollama
        model = "deepseek-r1:14b",
        endpoint = "http://172.17.0.1:11434/",
        options = {
          num_ctx = 16384,
        },
      },
      ["ollama-deepseek-32b"] = {
        __inherited_from = "ollama", -- Наследуем базовую конфигурацию ollama
        model = "deepseek-r1:32b",
        endpoint = "http://172.17.0.1:11434/",
        options = {
          num_ctx = 16384,
        },
      },
      ["ollama-qwen-32b"] = {
        __inherited_from = "ollama", -- Наследуем базовую конфигурацию ollama
        model = "qwen2.5:32b",
        endpoint = "http://172.17.0.1:11434/",
        api_key = "ollama",

        options = {
          num_ctx = 16384,
        },
      },
      ["ollama-qwen-1.5b"] = {
        __inherited_from = "ollama", -- Наследуем базовую конфигурацию ollama
        model = "qwen2.5:1.5b",
        endpoint = "http://172.17.0.1:11434/",
        api_key = "ollama",

        options = {
          num_ctx = 16384,
        },
      },
      ["ollama-qwen-14b"] = {
        __inherited_from = "ollama", -- Наследуем базовую конфигурацию ollama
        model = "qwen2.5:14b",
        endpoint = "http://172.17.0.1:11434/",
        api_key = "ollama",

        options = {
          num_ctx = 16384,
        },
      },
      ["ollama-deepseek-coder-v2-24b"] = {
        __inherited_from = "ollama", -- Наследуем базовую конфигурацию ollama
        model = "deepseek-coder-v2",
        endpoint = "http://172.17.0.1:11434/",
        api_key = "ollama",

        options = {
          num_ctx = 16384,
        },
      },
    },

    -- Стандартная конфигурация ollama для наследования
    ollama = {
      endpoint = "http://172.17.0.1:11434/",
      disable_tools = true, -- Для open-source моделей часто нужно отключать инструменты
    },

    -- Настройки поведения
    behaviour = {
      enable_cursor_planning_mode = true, -- включаем режим планирования курсора
      auto_suggestions = true, -- включаем автоподсказки
      auto_suggestions_respect_ignore = true, -- уважать файлы .gitignore и т.п.
    },

    mappings = {
      suggestion = {
        accept = "<M-CR>",
        next = "<M-n>",
        prev = "<M-p>",
        dismiss = "<C-]>",
      },
    },

    -- Настройка внешнего вида окон
    windows = {
      sidebar_header = {
        rounded = false,
        align = "left",
      },
      position = "left",
    },
  },

  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows

  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "echasnovski/mini.pick", -- for file_selector provider mini.pick
    "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    "ibhagwan/fzf-lua", -- for file_selector provider fzf
    "nvim-tree/nvim-web-devicons", -- или echasnovski/mini.icons
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
