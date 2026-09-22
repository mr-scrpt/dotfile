# Инструменты и агенты.

abbr -a d docker
abbr -a r rails
abbr -a h herdr
abbr -a a 'omarchy-agent --inline'
abbr -a mup 'MISE_MINIMUM_RELEASE_AGE=0 mise up'

# Агенты: короткие — как в bash-слое Omarchy, длинные — свои, без ограничений
abbr -a c 'opencode --auto'
abbr -a cx 'claude --permission-mode auto'
abbr -a cy 'codex --approve-for-me'
abbr -a ccx 'claude --dangerously-skip-permissions'
abbr -a ccxr 'claude --dangerously-skip-permissions --continue'

function n --description 'nvim; без аргументов — текущий каталог'
    if test (count $argv) -eq 0
        nvim .
    else
        nvim $argv
    end
end

function v --wraps nvim --description nvim
    nvim $argv
end

function cc-peek --description 'открыть последнюю картинку, вставленную в Claude Code'
    set -l f (command ls -t ~/.claude/image-cache/*/*.png 2>/dev/null | head -1)
    if test -z "$f"
        echo "no pasted image yet in ~/.claude/image-cache/"
        return 1
    end
    imv "$f" &
end
