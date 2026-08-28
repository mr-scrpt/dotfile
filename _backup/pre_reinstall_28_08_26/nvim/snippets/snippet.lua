local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

-- ОБНОВЛЕННАЯ ФУНКЦИЯ с обработкой дефисов
local function get_component_name()
  local filename = vim.fn.expand("%:t:r")
  local component_name = (filename == "index") and vim.fn.expand("%:h:t") or filename

  -- Преобразование в PascalCase/camelCase
  local processed_name = component_name
    -- Сначала обрабатываем дефисы: "use-attribute-create" -> "useAttributeCreate"
    :gsub(
      "%-(%w)",
      function(c)
        return string.upper(c)
      end
    )
    -- Затем обрабатываем точки: "handler.ts" -> "handlerTs"
    :gsub("%.(%w)", function(c)
      return string.upper(c)
    end)
    -- Делаем первую букву заглавной для PascalCase
    :gsub("^%l", string.upper)

  return processed_name
end

local react_snippets = {
  s(
    "rfce",
    fmt(
      [[
import type {{ ComponentProps }} from 'react';
type {}Props = ComponentProps<'div'>;
export const {} = (props: {}Props) => {{
  const {{ children, ...rest }} = props;
  return (
    <div {{...rest}}>
      {}
    </div>
  );
}};
      ]],
      {
        f(function()
          return get_component_name()
        end),
        f(function()
          return get_component_name()
        end),
        f(function()
          return get_component_name()
        end),
        i(1, "Content"),
      }
    )
  ),
}

ls.add_snippets("typescript", react_snippets)
ls.add_snippets("typescriptreact", react_snippets)
-- local ls = require("luasnip")
-- local s = ls.snippet
-- local i = ls.insert_node
-- local f = ls.function_node
-- local fmt = require("luasnip.extras.fmt").fmt
--
-- -- ОБНОВЛЕННАЯ ФУНКЦИЯ
-- local function get_component_name()
--   local filename = vim.fn.expand("%:t:r")
--   local component_name = (filename == "index") and vim.fn.expand("%:h:t") or filename
--
--   -- Преобразование в PascalCase (например, "text.animated" -> "TextAnimated")
--   local pascal_case_name = component_name
--     :gsub(
--       "%.(%w)",
--       function(c) -- Убираем точки и делаем следующую букву заглавной
--         return string.upper(c)
--       end
--     )
--     :gsub("^%l", string.upper) -- Делаем первую букву всей строки заглавной
--
--   return pascal_case_name
-- end
--
-- local react_snippets = {
--   s(
--     "rfce",
--     fmt(
--       [[
-- import type {{ ComponentProps }} from 'react';
--
-- type {}Props = ComponentProps<'div'>;
--
-- export const {} = (props: {}Props) => {{
--   const {{ children, ...rest }} = props;
--
--   return (
--     <div {{...rest}}>
--       {}
--     </div>
--   );
-- }};
--       ]],
--       {
--         f(function()
--           return get_component_name()
--         end),
--         f(function()
--           return get_component_name()
--         end),
--         f(function()
--           return get_component_name()
--         end),
--         i(1, "Content"),
--       }
--     )
--   ),
-- }
--
-- ls.add_snippets("typescript", react_snippets)
-- ls.add_snippets("typescriptreact", react_snippets)
-- -- local ls = require("luasnip")
-- -- local s = ls.snippet
-- -- local i = ls.insert_node
-- -- local f = ls.function_node
-- -- local fmt = require("luasnip.extras.fmt").fmt
-- --
-- -- local function get_component_name()
-- --   local filename = vim.fn.expand("%:t:r")
-- --   local component_name = (filename == "index") and vim.fn.expand("%:h:t") or filename
-- --   return component_name:gsub("^%l", string.upper)
-- -- end
-- --
-- -- local react_snippets = {
-- --   s(
-- --     "rfce",
-- --     fmt(
-- --       [[
-- -- import type {{ ComponentProps }} from 'react';
-- --
-- -- type {}Props = ComponentProps<'div'>;
-- --
-- -- export const {} = (props: {}Props) => {{
-- --   const {{ children, ...rest }} = props;
-- --
-- --   return (
-- --     <div {{...rest}}>
-- --       {}
-- --     </div>
-- --   );
-- -- }};
-- --       ]],
-- --       {
-- --         f(function()
-- --           return get_component_name()
-- --         end),
-- --         f(function()
-- --           return get_component_name()
-- --         end),
-- --         f(function()
-- --           return get_component_name()
-- --         end),
-- --         i(1, "Content"),
-- --       }
-- --     )
-- --   ),
-- -- }
-- --
-- -- ls.add_snippets("typescript", react_snippets)
-- -- ls.add_snippets("typescriptreact", react_snippets)
