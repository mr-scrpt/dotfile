# source ~/.config/fish/user_variables.fish
# source ~/.config/fish/abbreviations.fish

# Added by LM Studio CLI (lms)

set -gx PATH $PATH /home/mr/.lmstudio/bin
# End of LM Studio CLI section
# Привязка основанная на выводе fish_key_reader
bind \cs fzf_search_files_global_advanced
