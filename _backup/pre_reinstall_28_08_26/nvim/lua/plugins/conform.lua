return {
  {
    "stevearc/conform.nvim",
    opts = {
      -- 1. Назначаем форматеры
      formatters_by_ft = {
        -- ... твои другие настройки
        css = { "stylelint", "prettier" },
        scss = { "stylelint", "prettier" },
        html = { "prettier" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        json = { "prettier" },
        lua = { "stylua" },

        -- ▼▼▼ PHP просто использует 'prettier' ▼▼▼
        php = { "prettier" },
      },

      -- 2. Определяем 'prettier'
      formatters = {
        prettier = {
          -- 1. НЕ использовать Mason. Использовать $PATH
          mason = false,

          -- 2. Динамически добавляем аргументы
          prepend_args = function(ctx)
            if ctx.ft == "php" then
              -- Если файл - PHP, добавляем наши "волшебные" флаги
              return { "--plugin=@prettier/plugin-php", "--parser=html" }
            end

            -- Для всех других файлов - ничего не добавляем
            return {}
          end,

          -- 3. Переопределяем условие (чтобы убрать 'unavailable')
          condition = function(ctx)
            if ctx.ft == "php" then
              return true
            end

            -- Для JS, CSS и т.д. можно оставить проверку по умолчанию,
            -- но 'true' тоже безопасно, т.к. мы знаем, что он в $PATH
            return true
          end,
        },
      },
    },
  },
}
