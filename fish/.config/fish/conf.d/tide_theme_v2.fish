# if status is-interactive
#
#     # --- PALETTE (Global variables for reuse) ---
#     set -g base 1e1e2e
#     set -g surface0 313244
#     set -g surface1 45475a
#     set -g text cdd6f4
#     set -g subtext0 a6adc8
#     set -g blue 89b4fa
#     set -g green a6e3a1
#     set -g red f38ba8
#     set -g peach fab387
#     set -g mauve cba6f7
#     set -g overlay0 6c7086
#
#     # --- 1. CONFIGURATION ---
#     # Global (-g) overrides Universal (-U)
#
#     set -g tide_left_prompt_items pwd git newline character
#     set -g tide_right_prompt_items status cmd_duration context jobs direnv node python rustc java php go gcloud kubectl toolbox terraform aws nix_shell crystal elixir zig time
#
#     set -g tide_left_prompt_separator_diff_color " "
#     set -g tide_left_prompt_separator_same_color " "
#     set -g tide_left_prompt_prefix ""
#     set -g tide_left_prompt_suffix " "
#
#     # --- 2. PWD ---
#     set -g tide_pwd_bg_color normal
#     set -g tide_pwd_color_anchors $blue
#     set -g tide_pwd_color_dirs $blue
#     set -g tide_pwd_color_truncated_dirs $overlay0
#     # set -g tide_pwd_icon " "
#     # set -g tide_pwd_icon_home " "
#
#     set -g tide_pwd_suffix " "
#
#     # --- 3. GIT ---
#     set -g tide_git_bg_color $surface0
#     set -g tide_git_bg_color_unstable $peach
#     set -g tide_git_bg_color_urgent $red
#     set -g tide_git_color_branch $green
#     set -g tide_git_color_operation $red
#     set -g tide_git_color_staged $green
#     set -g tide_git_color_dirty $peach
#     set -g tide_git_color_untracked $blue
#     set -g tide_git_color_conflicted $red
#     set -g tide_git_color_stash $mauve
#     set -g tide_git_color_upstream $green
#     set -g tide_git_icon " "
#
#     # --- 4. OTHERS ---
#     set -g tide_character_color $green
#     set -g tide_character_color_failure $red
#     set -g tide_time_bg_color normal
#     set -g tide_time_color $subtext0
#     set -g tide_cmd_duration_bg_color normal
#     set -g tide_cmd_duration_color $subtext0
#     set -g tide_status_bg_color normal
#     set -g tide_status_color $green
#     set -g tide_status_color_failure $red
#     set -g tide_context_bg_color $surface0
#     set -g tide_context_color_default $text
#
#     # Vim Mode
#     set -g tide_vi_mode_bg_color_default normal
#     set -g tide_vi_mode_bg_color_insert normal
#     set -g tide_vi_mode_bg_color_visual normal
#     set -g tide_vi_mode_bg_color_replace normal
#     set -g tide_vi_mode_color_default $text
#     set -g tide_vi_mode_color_insert $green
#     set -g tide_vi_mode_color_visual $peach
#     set -g tide_vi_mode_color_replace $red
#
#     # Languages
#     set -g tide_node_bg_color normal
#     set -g tide_node_color $green
#     set -g tide_python_bg_color normal
#     set -g tide_python_color $blue
#     set -g tide_go_bg_color normal
#     set -g tide_go_color $blue
#     set -g tide_rustc_bg_color normal
#     set -g tide_rustc_color $red
#     set -g tide_java_bg_color normal
#     set -g tide_java_color $peach
#
#     tide reload
# end
