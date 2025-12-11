#!/usr/bin/env fish

# Function to reload Fish configuration when receiving USR1 signal
function reload_config_on_sigusr1 --on-signal SIGUSR1
    # Source the main config file
    source ~/.config/fish/config.fish
    
    # Optional: Echo confirmation (will appear in terminal)
    echo "🐟 Fish config reloaded via signal"
end
