# Выполняется ПОСЛЕ всех conf.d — включая conf.d плагинов fisher.
# Поэтому перенастройка биндингов живёт здесь, а не в conf.d/10-init.fish:
# fzf.fish в своём conf.d вешает дефолты (в т.ч. Ctrl+R) поверх atuin.

status is-interactive; or exit

# Ctrl+R отдан atuin, поиск процессов не нужен.
# Остаётся: Ctrl+Alt+F каталоги, Ctrl+Alt+L git log,
# Ctrl+Alt+S git status, Ctrl+V переменные.
if functions -q fzf_configure_bindings
    fzf_configure_bindings --history= --processes=
end

# fzf_configure_bindings стирает Ctrl+R вместе со своими дефолтами,
# поэтому atuin возвращаем сюда — после него.
if functions -q _atuin_search
    bind ctrl-r _atuin_search
    bind -M insert ctrl-r _atuin_search
end

# Ctrl+Backspace — удалить слово. Остальное (Ctrl+←/→ по токенам,
# Shift+Enter перенос строки) fish 4.x уже умеет из коробки.
bind -M insert ctrl-backspace backward-kill-word
bind -M default ctrl-backspace backward-kill-word

fastfetch
