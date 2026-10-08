# dotfile

Personal config for the Omarchy workstation, managed with GNU stow.
One package per app; each package mirrors `$HOME` (`system` mirrors `/`).
Only files we actually changed live here — stock Omarchy files stay in the
system so `omarchy update` / `omarchy refresh` keep working.

## Two kinds of package

Which one a package is decides how it is stowed. Judge by the target directory,
not by the app:

**Shared directory** — the system also ships files there (`~/.config/hypr` from
Omarchy, `~/.local/bin` from mise, `~/.config/omarchy`). Only the files we
changed live here, and stow links them one by one; the directory itself stays
real so its owner keeps writing into it. Adding a stock file to the repo just
to "complete" the package is wrong — it would freeze a file `omarchy update`
maintains.

**Ours entirely** — the system ships nothing there (`~/.config/fish`,
`~/.config/hass`, `~/.config/proxmox`, `~/.hermes/plugins/*`). The whole
directory is the package and stow folds it into a single symlink, so anything
created there later is tracked by default and cannot be forgotten.

That second kind has one condition: **no foreign writer inside the directory**.
A tool that writes next to our files (fisher installing plugins, a daemon
rewriting state) would be writing straight into the repo. Point it elsewhere
first — fisher takes `$fisher_path`, so plugins go to `~/.local/share/fisher`
and only `fish_plugins` (our list) stays in the repo; `fish -c 'fisher update'`
restores them on a fresh machine. If a writer cannot be moved out, the package
falls back to the shared-directory rules.

## Install

    git clone --recurse-submodules git@github.com:mr-scrpt/dotfile.git ~/Hellkitchen/dotfile
    cd ~/Hellkitchen/dotfile
    stow -t ~ hypr ghostty fish starship git omarchy bin systemd herdr hass proxmox ssh hermes pypr yazi
    stow --no-folding -t ~ nvim
    sudo stow -t / system
    sed -i 's/^-- omarchy_default_bindings = false/omarchy_default_bindings = false/' ~/.config/hypr/hyprland.lua
    herdr integration install claude && herdr integration install hermes
    ya pkg install

The `sed` line switches Omarchy's stock keybindings off with its own flag: the
whole keymap lives in `hypr/.config/hypr/bindings.lua` (see `hypr/README.md`).
`hyprland.lua` itself is not stored here because Omarchy migrations rewrite it.

The last two lines are steps, not packages. `ya pkg install` fetches the yazi
plugins pinned in `yazi/.config/yazi/package.toml` (the plugin code itself is
gitignored). herdr generates its integrations
(a SessionStart hook in `~/.claude`, a plugin in `~/.hermes/plugins`, one entry
each in `~/.claude/settings.json` and `~/.hermes/config.yaml`) and overwrites
them on every herdr update, so they are never stored here. They let herdr
reopen each pane's claude/hermes conversation after a reboot
(`[session] resume_agents_on_restore`, on by default); check with
`herdr integration status`.

Shared-directory packages must be stowed with `--no-folding` if their whole
subtree happens to be new, otherwise stow folds them into a directory symlink
and the system's own files would land in the repo.

## Packages

| package | kind | target                              | what                                                              |
|---------|------|-------------------------------------|-------------------------------------------------------------------|
| hypr    | shared | ~/.config/hypr/                   | bindings.lua — the whole keymap (stock bindings off, see hypr/README.md), input.lua, looknfeel.lua (scrolling width presets), monitors.lua, autostart.lua (starts pypr) |
| ghostty | shared | ~/.config/ghostty/config          | font size, fish as the terminal's shell, copy-on-select to the clipboard                           |
| fish    | ours | ~/.config/fish/                     | interactive shell (login shell stays bash): eza/zoxide nav, fzf.fish, atuin on Ctrl+R, herdr layouts, ssh reconnect wrapper |
| git     | shared | ~/.config/git/config              | user name / email                                                 |
| starship| shared | ~/.config/starship.toml           | symlink into the active theme's rendered starship.toml (see omarchy/themed) |
| omarchy | shared | ~/.config/omarchy/                | shell.json (idle, local-llm widget), bar/modules/local-llm.qml, defaults/agent, themed/starship.toml.tpl |
| bin     | shared | ~/.local/bin/                     | hermes-local*, llama-local*, llama-probe, llama-speed, omarchy-big-monitor, omarchy-ua-layout (UA layout on demand: menu Trigger → Toggle → Ukrainian Layout, `omarchy menu summon ua`; flag in XDG_RUNTIME_DIR read by hypr/input.lua, resets on reboot) |
| systemd | shared | ~/.config/systemd/user/           | llama-local.service (llama.cpp server for Hermes)                 |
| herdr   | shared | ~/.config/herdr/                  | config.toml (prefix ctrl+a) + devspace plugin (dotfile/config/work workspaces, fzf dev picker) |
| hass    | ours | ~/.config/hass/                     | Home Assistant CLI config                                         |
| proxmox | ours | ~/.config/proxmox/                  | Proxmox API config                                                |
| ssh     | shared | ~/.ssh/config                     | hosts for the homelab                                             |
| hermes  | ours | ~/.hermes/plugins/, ~/.hermes/skills/ | custom Hermes plugins + skills (shopping research); see hermes/README.md |
| pypr    | ours | ~/.config/pypr/                     | pyprland (AUR `pyprland`): bottom widgets — scratchpads sliding in from the bottom edge (yazi on SUPER+CTRL+N) |
| yazi    | ours | ~/.config/yazi/                     | dual pane via split-tabs.yazi (Ctrl+S toggle, Tab switch, F5/F6 copy/move), on at startup when `YAZI_DUAL_PANE=1` (the bottom widget); archives: pack with compress.yazi (`c a`, `c p` with password), unpack with unar into a folder named after the archive (legacy name encodings, no `__MACOSX`); `g`-groups for jumps; Downloads sorted newest first; `y` also puts files on the Wayland clipboard; Ctrl+N drags via ripdrag (AUR). Plugins from package.toml are restored by `ya pkg install`; only our own `folder-rules.yazi` is stored |
| nvim    | shared | ~/.config/nvim/                   | additions to Omarchy's LazyVim: neo-tree as a float + favorites, render-markdown, en+ru spell, copy on mouse select; see nvim/README.md |
| system  | shared | /etc/                             | mnt-station SMB automount, chromium password-manager policy       |

Not a stow package: `homeassistant/` is a **private git submodule**
(`mr-scrpt/homeassistant`) — the Home Assistant config (packages, blueprints,
tools) deployed to the HA host by `homeassistant/deploy.sh`, not into `$HOME`.
It stays private because it maps the house: devices, presence logic, the
webhook domain. Without access to it, a clone simply leaves the folder empty.
After committing inside it, pin the new revision here with
`git add homeassistant && git commit`.

## Rules

- Secrets never go here: they live in `~/.local/share/secrets/` and are
  referenced by path.
- The login shell stays bash — Omarchy's boot chain (SDDM, /etc/profile.d,
  default/bash/rc) is built on it. Fish is opted into per terminal:
  `command` in ghostty, `[terminal] default_shell` in herdr. Never `chsh`.
- Anything that must follow the active theme is a template in
  `~/.config/omarchy/themed/*.tpl` using `{{ accent }}`-style placeholders;
  never hardcode a palette (it would break the other themes).
- After `omarchy refresh <x>` on a stowed file, Omarchy writes through the
  symlink into this repo: review with `git diff`, keep or revert.
- Nothing we own is ever created directly in `~/.config` — it goes into a
  package and reaches `$HOME` through stow. That includes a file whose content
  is not ours, such as the `starship.toml` symlink into the theme.
- Add a package = decide its kind first (see above), create
  `<pkg>/<path-under-home>`, move the file in, `stow -t ~ <pkg>` (add
  `--no-folding` for a shared-directory package). The herdr `dotfile` workspace
  picks new packages up automatically.
- Audit the convention with `readlink -f`, not `stat -c %i` (`%i` does not
  follow symlinks, so every correct link looks like a mismatch):
  `readlink -f <repo file>` must equal `readlink -f ~/<rel path>`.
