function cc-peek --description "Open the most recently pasted image in Claude Code"
    set -l f (command ls -t ~/.claude/image-cache/*/*.png 2>/dev/null | head -1)
    if test -z "$f"
        echo "no pasted image yet in ~/.claude/image-cache/"
        return 1
    end
    imv "$f" &
end
