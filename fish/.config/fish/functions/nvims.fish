# Алиасы для разных конфигураций Neovim
alias nvim-lazy="NVIM_APPNAME=LazyVim nvim"
alias nvim-kick="NVIM_APPNAME=kickstart nvim"
alias nvim-chad="NVIM_APPNAME=NvChad nvim"
alias nvim-astro="NVIM_APPNAME=AstroNvim nvim"

# Функция выбора конфигурации через fzf
function nvims
    set -l items default kickstart LazyVim NvChad AstroNvim
    set -l config (printf "%s\n" $items | fzf --prompt=" Neovim Config  " --height=~50% --layout=reverse --border --exit-0)

    if test -z "$config"
        echo "Nothing selected"
        return 0
    end

    if test "$config" = "default"
        set config ""
    end

    NVIM_APPNAME=$config nvim $argv
end

# Привязка клавиш (Ctrl+A)
bind \ca 'nvims'
