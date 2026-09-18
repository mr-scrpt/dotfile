# dotfile

Personal config for the Omarchy workstation, managed with GNU stow.
One package per app; each package mirrors `$HOME` (`system` mirrors `/`).
Only files we actually changed live here — stock Omarchy files stay in the
system so `omarchy update` / `omarchy refresh` keep working.

## Install

    cd ~/Hellkitchen/dotfile
    stow -t ~ hypr ghostty git omarchy bin systemd herdr hass proxmox ssh hermes
    sudo stow -t / system

Stow links individual files, so real directories such as `~/.config/hypr`
and `~/.local/bin` remain writable by Omarchy and mise.

## Packages

| package | target                              | what                                                              |
|---------|-------------------------------------|-------------------------------------------------------------------|
| hypr    | ~/.config/hypr/                     | bindings.lua (us/ru on Ctrl+Space, scrolling layout keys, local LLM), input.lua, looknfeel.lua |
| ghostty | ~/.config/ghostty/config            | font size                                                         |
| git     | ~/.config/git/config                | user name / email                                                 |
| omarchy | ~/.config/omarchy/                  | shell.json (idle, local-llm widget), bar/modules/local-llm.qml, defaults/agent |
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
- After `omarchy refresh <x>` on a stowed file, Omarchy writes through the
  symlink into this repo: review with `git diff`, keep or revert.
- Add a package = create `<pkg>/<path-under-home>`, move the file in, `stow -t ~ <pkg>`.
  The herdr `dotfile` workspace picks new packages up automatically.
