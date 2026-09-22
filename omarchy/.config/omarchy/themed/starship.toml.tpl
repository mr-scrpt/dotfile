# Rendered by omarchy-theme-set-templates into
# ~/.local/state/omarchy/current/theme/starship.toml on every theme switch.
# Colors come from the active theme's colors.toml — never hardcode a palette here.

add_newline = true
command_timeout = 200

format = """
$directory\
$git_branch\
$git_status\
$line_break\
$character"""

palette = "omarchy"

[palettes.omarchy]
accent = "{{ accent }}"
muted = "{{ muted }}"
fg = "{{ foreground }}"
bright_fg = "{{ bright_fg }}"
red = "{{ red }}"
green = "{{ green }}"
yellow = "{{ yellow }}"
blue = "{{ blue }}"
magenta = "{{ magenta }}"
cyan = "{{ cyan }}"

[directory]
style = "bold blue"
truncation_length = 3
truncation_symbol = "…/"
truncate_to_repo = false
format = "[$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
style = "bold magenta"
format = "on [$symbol$branch]($style) "

[git_status]
style = "bold red"
format = "([$all_status$ahead_behind]($style) )"
up_to_date = ""
conflicted = "󰞇 "
ahead = "⇡"
behind = "⇣"
diverged = "↕"
untracked = "[?](yellow) "
modified = "[!](yellow) "
staged = "[+](green) "
renamed = "» "
deleted = "✘ "
stashed = "≡ "

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
vimcmd_symbol = "[❮](bold accent)"
