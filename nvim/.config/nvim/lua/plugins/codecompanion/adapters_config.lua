local adapters_config = {
  defaults = {
    stream = true,
    default_type = "openai_compatible",

    types = {
      openai_compatible = {
        url = "http://localhost:1234",
        api_key = "EMPTY",
      },
      ollama = {},
    },
  },

  -- Конфигурация доступных адаптеров
  models = {
    {
      id = "gemma3",
      type = "openai_compatible",
      name = "lm_studio",
      model_default = "gemma-3-27b-it-qat",
      -- stream, url и api_key берутся из defaults
    },
    {
      id = "qwen3_30b",
      type = "openai_compatible",
      name = "qwen3-30b(MOE)",
      api_key = "qwen3-30b-a3b", -- переопределяем api_key из defaults
      model_default = "qwen3-30b-a3b@q6_k",
    },
    {
      id = "qwen3",
      type = "openai_compatible",
      name = "qwen3-14b",
      api_key = "qwen3-14b", -- переопределяем api_key из defaults
      model_default = "qwen3-14b",
    },
    {
      id = "ollama",
      type = "ollama",
      name = "llama3.2:1b",
      model_default = "llama3.2:1b",
    },
  },

  -- Выбор активных адаптеров для разных стратегий
  active = {
    chat = "qwen3_30b",
    inline = "qwen3_30b",
  },
}

return adapters_config
