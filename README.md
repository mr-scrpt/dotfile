# dotfile

Personal config for the Omarchy workstation, managed with GNU stow.
One package per app; each package mirrors `$HOME` (`system` mirrors `/`).
Only files we actually changed live here — stock Omarchy files stay in the
system so `omarchy update` / `omarchy refresh` keep working.

## Install

    cd ~/Hellkitchen/dotfile
    stow -t ~ hypr ghostty fish git omarchy bin systemd herdr hass proxmox ssh hermes
    sudo stow -t / system

Stow links individual files, so real directories such as `~/.config/hypr`
and `~/.local/bin` remain writable by Omarchy and mise.

## Packages

| package | target                              | what                                                              |
|---------|-------------------------------------|-------------------------------------------------------------------|
| hypr    | ~/.config/hypr/                     | bindings.lua (us/ru on Ctrl+Space, scrolling layout keys, local LLM), input.lua, looknfeel.lua |
| ghostty | ~/.config/ghostty/config            | font size, fish as the terminal's shell                           |
| fish    | ~/.config/fish/                     | interactive shell (login shell stays bash): eza/zoxide nav, fzf.fish, atuin on Ctrl+R, herdr layouts, ssh reconnect wrapper |
| git     | ~/.config/git/config                | user name / email                                                 |
| omarchy | ~/.config/omarchy/                  | shell.json (idle, local-llm widget), bar/modules/local-llm.qml, defaults/agent, themed/starship.toml.tpl |
| bin     | ~/.local/bin/                       | hermes-local*, llama-local*, llama-probe, llama-speed             |
| systemd | ~/.config/systemd/user/             | llama-local.service (llama.cpp server for Hermes)                 |
| herdr   | ~/.config/herdr/                    | config.toml (prefix ctrl+a) + devspace plugin (dotfile/config/work workspaces, fzf dev picker) |
| hass    | ~/.config/hass/                     | Home Assistant CLI config                                         |
| proxmox | ~/.config/proxmox/                  | Proxmox API config                                                |
| ssh     | ~/.ssh/config                       | hosts for the homelab                                             |
| hermes  | ~/.hermes/plugins/, ~/.hermes/skills/ | custom Hermes plugins + skills (shopping research); see hermes/README.md |
| system  | /etc/                               | mnt-station SMB automount, chromium password-manager policy       |

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
- Add a package = create `<pkg>/<path-under-home>`, move the file in, `stow -t ~ <pkg>`.
  The herdr `dotfile` workspace picks new packages up automatically.
