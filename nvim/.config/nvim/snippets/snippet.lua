local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

-- Улучшенная функция для преобразования имени файла в PascalCase
local function capitalize(str)
  -- Разбиваем имя файла на части по точкам
  local parts = vim.split(str, ".", { plain = true })
  -- Удаляем последний элемент (расширение файла)
  local lastPart = parts[#parts]
  if lastPart:match("tsx?$") or lastPart:match("jsx?$") then
    table.remove(parts)
  end

  -- Преобразуем каждую часть в PascalCase и объединяем
  local result = ""
  for _, part in ipairs(parts) do
    -- Для каждой части: первая буква заглавная, остальные без изменений
    result = result .. part:gsub("^%l", string.upper)
  end

  return result
end

local react_snippets = {
  s(
    "rfce",
    fmt(
      [[
import {{ FC, HTMLAttributes }} from 'react'

interface {}Props extends HTMLAttributes<HTMLDivElement> {{}}

export const {}: FC<{}Props> = (props) => {{
    return (
        <div>{}</div>
    )
}}
            ]],
      {
        f(function(_, snip)
          local filename = vim.fn.expand("%:t")
          return capitalize(filename)
        end),
        f(function(_, snip)
          local filename = vim.fn.expand("%:t")
          return capitalize(filename)
        end),
        f(function(_, snip)
          local filename = vim.fn.expand("%:t")
          return capitalize(filename)
        end),
        i(1, "content"),
      }
    )
  ),
}

ls.add_snippets("typescript", react_snippets)
ls.add_snippets("typescriptreact", react_snippets)
ls.add_snippets("javascript", react_snippets)
ls.add_snippets("javascriptreact", react_snippets)
-- local ls = require("luasnip")
-- local s = ls.snippet
-- local i = ls.insert_node
-- local f = ls.function_node
-- local fmt = require("luasnip.extras.fmt").fmt
--
-- -- Функция для преобразования имени файла в PascalCase
-- local function capitalize(str)
--   return str:gsub("^%l", string.upper)
-- end
--
-- -- React Function Component сниппет
-- local react_snippets = {
--   s(
--     "rfce",
--     fmt(
--       [[
-- import {{ FC, HTMLAttributes }} from 'react'
--
-- interface {}Props extends HTMLAttributes<HTMLDivElement> {{}}
--
-- export const {}: FC<{}Props> = (props) => {{
--   return (
--     <div>{}</div>
--   )
-- }}
--   ]],
--       {
--         f(function(_, snip)
--           local filename = vim.fn.expand("%:t:r")
--           return capitalize(filename)
--         end),
--         f(function(_, snip)
--           local filename = vim.fn.expand("%:t:r")
--           return capitalize(filename)
--         end),
--         f(function(_, snip)
--           local filename = vim.fn.expand("%:t:r")
--           return capitalize(filename)
--         end),
--         i(1, "content"),
--       }
--     )
--   ),
-- }
--
-- -- Добавляем сниппет для типов файлов
-- ls.add_snippets("typescript", react_snippets)
-- ls.add_snippets("typescriptreact", react_snippets)
-- ls.add_snippets("javascript", react_snippets)
-- ls.add_snippets("javascriptreact", react_snippets)
