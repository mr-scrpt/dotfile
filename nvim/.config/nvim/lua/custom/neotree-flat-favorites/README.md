# Flat Favorites для Neo-tree

Альтернативная реализация избранного для neo-tree, где каждый добавленный элемент отображается как отдельный корень на верхнем уровне.

## 🎯 Отличия от обычного favorites

**Обычный favorites:**
- Сохраняет ВСЕ вложенные файлы и папки в JSON
- Показывает полную иерархию от pwd/git root
- Файл может раздуться до тысяч записей

**Flat favorites:**
- Сохраняет ТОЛЬКО явно добавленные элементы (корни)
- Каждый корень на верхнем уровне без промежуточной иерархии
- Содержимое папок загружается динамически через neo-tree API
- Компактный JSON файл

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
- `<leader>fv` - открыть Flat Favorites
- `S` (Shift+s) - добавить в flat favorites (в файловом менеджере или внутри flat favorites)
- `D` (Shift+d) - удалить из flat favorites

### Пример:

1. Откройте файловый менеджер: `<leader>fe`
2. Перейдите к `/tmp/neotree-test/src/domain`
3. Нажмите `Shift+S`
4. Откройте flat favorites: `<leader>fv`
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

## 🔧 Как это работает

1. **Хранение:** В JSON сохраняются только пути добавленных корней
2. **Построение дерева:** Используется `file_items.create_item` API neo-tree
3. **Автоматическая иерархия:** neo-tree сам загружает содержимое при раскрытии
4. **Перемещение:** Созданные элементы перемещаются на верхний уровень root.children

## 🧪 Тестирование

Для тестирования создан статичный файл с тремя тестовыми папками.
При необходимости можно вручную редактировать:
```bash
nvim ~/.local/share/nvim/neotree-flat-favorites.json
```

## 🔄 Обновление при изменениях

При каждом открытии `<leader>fv`:
- Читается JSON с корнями
- Строится актуальное дерево из ФС
- Отображается в neo-tree

Изменения в файловой системе видны сразу при следующем открытии.
