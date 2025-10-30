# Flat Favorites для Neo-tree

Умная система избранного для neo-tree с per-project storage и автоочисткой.

## 🎯 Ключевые особенности

**Компактное хранение:**
- Сохраняет ТОЛЬКО явно добавленные элементы (корни)
- НЕ сохраняет вложенные файлы и папки
- Содержимое загружается динамически при открытии

**Per-project storage:**
- Каждый проект (git root или cwd) имеет отдельный файл
- Favorites не смешиваются между проектами
- Файлы: `~/.local/share/nvim/neotree-favorites/{project_name}.json`

**Автоочистка:**
- При загрузке автоматически удаляет несуществующие пути
- Предотвращает накопление мусора
- Уведомляет о количестве очищенных элементов

## 📁 Структура

```
/home/mr/.config/nvim/lua/custom/neotree-flat-favorites/
├── manager.lua      # Управление данными (хранит только корни)
├── commands.lua     # Команды добавления/удаления
└── init.lua         # Neo-tree source

/home/mr/.local/share/nvim/lazy/neo-tree.nvim/lua/neo-tree/sources/flat_favorites/
├── init.lua (symlink)
├── components.lua
└── commands.lua
```

## 💾 Файл данных

`~/.local/share/nvim/neotree-flat-favorites.json`

Пример:
```json
{
  "/tmp/neotree-test/src/domain": {
    "type": "directory",
    "added_at": 1730295600
  },
  "/tmp/neotree-test/src/presentation/web/react": {
    "type": "directory",
    "added_at": 1730295700
  }
}
```

## 🎮 Использование

### Hotkeys:

**Открытие:**
- `<leader>E` - открыть Favorites (📦)
- `<leader>e` - открыть файловый менеджер

**Toggle (добавить/удалить):**
- `s` - переключить избранное (работает везде)

**Информация:**
- `I` (Shift+i) - показать информацию о проекте (внутри Neo-tree)

**Переключение между табами:**
- `<` - предыдущая вкладка (Files ← Favorites ← Buffers ← Git)
- `>` - следующая вкладка (Files → Favorites → Buffers → Git)

**В файловом менеджере (`<leader>e`):**
- `s` - добавить/удалить из favorites (📦)
- Индикатор 📦 показывает что элемент в избранном

**В favorites (`<leader>E`):**
- `s` - удалить из favorites
- При удалении дерево автоматически обновляется

### Индикаторы:
В обычном файловом менеджере (`<leader>e`) элементы помечаются:
- 📦 - в избранном (существует)
- ⚠️  - в избранном, но удален/перемещен (нажмите `s` чтобы убрать)

### Пример:

1. Откройте файловый менеджер: `<leader>e`
2. Перейдите к `/tmp/neotree-test/src/domain`
3. Нажмите `s` - папка добавится в favorites, появится индикатор 📦
4. Откройте favorites: `<leader>E`
5. Увидите:
   ```
   📦 Flat Favorites
   └── domain
       ├── Product.ts
       └── User.ts
   ```

Добавьте еще `/tmp/neotree-test/src/presentation/web/react`:
```
📦 Flat Favorites
├── domain
│   ├── Product.ts
│   └── User.ts
└── react
    └── components
        ├── Button.tsx
        └── Input.tsx
```

Обе папки на верхнем уровне!

### Пример с неактуальными элементами:

Если папка была удалена или перемещена:

**В файловом менеджере (`<leader>e`):**
```
src/
  ├── domain  ⚠️
  └── config  📦
```

**При открытии favorites (`<leader>E`):**
```
⚠️  Found 1 invalid paths in favorites (deleted/moved). Press 's' to remove.

📦 Flat Favorites
├── ⚠️  domain  (пустая, недоступна)
└── config
    └── app.json
```

Нажмите `s` на `⚠️  domain` чтобы удалить из favorites!

## 🔧 Как это работает

**Хранение данных:**
1. Определяется project root (git root или cwd)
2. Создается файл `~/.local/share/nvim/neotree-favorites/{project_name}.json`
3. В JSON сохраняются ТОЛЬКО пути явно добавленных элементов
4. Вложенное содержимое НЕ сохраняется - загружается динамически

**Построение дерева:**
1. Читается JSON с корнями для текущего проекта
2. Автоочистка - удаляются несуществующие пути
3. Рекурсивно загружается содержимое каждого корня из ФС
4. Отображается в neo-tree с каждым корнем на верхнем уровне

**Контроль размера:**
- При загрузке проверяется размер файла
- Если >15 MB - выводится предупреждение
- Предлагается очистить неактуальные элементы

**Индикация неактуальных элементов:**
- При загрузке проверяется существование путей
- Несуществующие пути помечаются как ⚠️  (invalid)
- Можно удалить нажатием `s` как обычно
- Уведомление о количестве неактуальных элементов

## 💾 Структура хранения

**Директория:** `~/.local/share/nvim/neotree-favorites/`

**Файлы (примеры):**
- `home_user_project1.json` - favorites для `/home/user/project1`
- `home_user_project2.json` - favorites для `/home/user/project2`

**Пример содержимого файла:**
```json
{
  "/home/user/project1/src": {
    "type": "directory",
    "added_at": 1730295600
  },
  "/home/user/project1/config": {
    "type": "directory",
    "added_at": 1730295700
  }
}
```

**Пример с invalid элементом:**
```json
{
  "/home/user/project1/src": {
    "type": "directory",
    "added_at": 1730295600,
    "invalid": false
  },
  "/home/user/project1/old_folder": {
    "type": "directory",
    "added_at": 1730295500,
    "invalid": true
  }
}
```

**Преимущества:**
- ✅ Компактно - только корни, не тысячи файлов
- ✅ Изолировано - каждый проект отдельно
- ✅ Контроль размера - предупреждение при >15 MB
- ✅ Визуальная индикация - ⚠️  для удаленных/перемещенных
- ✅ Быстро - кеш для каждого проекта

## 📊 Информация о проекте

Откройте Neo-tree (`<leader>E` или `<leader>e`) и нажмите `I` (Shift+i) чтобы увидеть:
- Project root
- Файл данных
- Количество favorites
- Git проект или нет
- Storage type и auto-cleanup status
