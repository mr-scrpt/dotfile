# nvim

Our additions on top of Omarchy's LazyVim (`omarchy-nvim` seeds `~/.config/nvim`
from `/etc/skel`). Shared package: Omarchy migrations, `:LazyExtras` and lazy.nvim
write into that directory, so only our own files live here, linked one by one.

| file | what |
|------|------|
| `lua/plugins/neo-tree.lua` | explorer as a float: `<leader>e` float, `<leader>E` right panel; in tree `l` focus preview, `P` float preview, `o` system open, `R` grug-far in dir, `b` buffers float; size/date/type columns appear as the window widens |
| `lua/plugins/neo-tree-fav.lua` | own plugin mr-scrpt/neo-tree-fav: `F` in tree toggles a favorite (⭐), `<leader>F` favorites float, Favorites tab in the source bar; lists per project in `~/.local/state/nvim/neo-tree-fav/` |
| `lua/plugins/markdown.lua` | render-markdown.nvim: rendered headings/tables/code in the buffer, `<leader>um` toggle |
| `plugin/mouse-copy.lua` | releasing a mouse selection (drag, double/triple click) copies it to the clipboard, like herdr/Ghostty (`clipboard=autoselect` is unimplemented, neovim#2325; mapping from `:h faq`) |
| `plugin/spell.lua` | `spelllang = en,ru` (LazyVim spell-checks markdown in English only) |

Configure through `opts`/`keys` only; a `config` field replaces LazyVim's and
drops its handlers. Extras go through `:LazyExtras` (`lazyvim.json`, stock).

Install / restore:

    stow --no-folding -t ~ nvim
    nvim --headless -u NONE +'lua require("nvim.spellfile").config({confirm=false}); require("nvim.spellfile").get("ru")' +'sleep 20' +qa

`omarchy-nvim-refresh` moves `~/.config/nvim` to a backup, links included —
run `stow` again after it.
