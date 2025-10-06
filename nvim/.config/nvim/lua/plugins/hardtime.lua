-- lua/plugins/hardtime.lua
return {
  "m4xshen/hardtime.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    -- 1. Устанавливаем лимит в одно нажатие
    max_count = 1,

    -- 2. Снимаем полную блокировку со стрелок, переопределяя стандартные настройки
    disabled_keys = {
      ["<Up>"] = false,
      ["<Down>"] = false,
      ["<Left>"] = false,
      ["<Right>"] = false,
    },

    -- 3. Явно добавляем и hjkl, и стрелки в список отслеживаемых клавиш
    --    в Нормальном (n) и Визуальном (v) режимах
    restricted_keys = {
      ["h"] = { "n", "v" },
      ["j"] = { "n", "v" },
      ["k"] = { "n", "v" },
      ["l"] = { "n", "v" },
      ["<Up>"] = { "n", "v" },
      ["<Down>"] = { "n", "v" },
      ["<Left>"] = { "n", "v" },
      ["<Right>"] = { "n", "v" },
    },
  },
}
