-- adapters_setup.lua
local M = {}

function M.setup_adapters(adapters_config)
  local result = {}
  local defaults = adapters_config.defaults
  local default_type = defaults.default_type or "openai_compatible"

  for _, adapter_config in ipairs(adapters_config.models) do
    local base_type = adapter_config.type or default_type
    local type_defaults = defaults.types[base_type] or {}

    local config = {
      name = adapter_config.name,
      opts = {
        stream = adapter_config.stream or defaults.stream,
      },
      schema = {
        model = {
          default = adapter_config.model_default,
        },
      },
    }

    if base_type == "openai_compatible" then
      config.env = {
        api_key = adapter_config.api_key or type_defaults.api_key,
        url = adapter_config.url or type_defaults.url,
      }
    end

    result[adapter_config.id] = function()
      return require("codecompanion.adapters").extend(base_type, config)
    end
  end

  return result
end

return M
