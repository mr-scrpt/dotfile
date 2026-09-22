# Git. `ga`/`gd` — worktree-пара из bash-слоя Omarchy.

abbr -a g git
abbr -a gcm 'git commit -m'
abbr -a gcam 'git commit -a -m'
abbr -a gcad 'git commit -a --amend'

function ga --description 'создать worktree с новой веткой и перейти в него'
    if test -z "$argv[1]"
        echo "Usage: ga [branch name]"
        return 1
    end

    set -l branch $argv[1]
    set -l base (basename $PWD)
    set -l wt_path "../$base--$branch"

    git worktree add -b $branch $wt_path
    and mise trust $wt_path
    and cd $wt_path
end

function gd --description 'удалить текущий worktree вместе с веткой'
    if gum confirm "Remove worktree and branch?"
        set -l cwd (pwd)
        set -l worktree (basename $cwd)

        set -l root (string replace -r '--.*' '' $worktree)
        set -l branch (string replace -r '.*?--' '' $worktree)

        if test "$root" != "$worktree"
            cd "../$root"
            git worktree remove $cwd --force; or return 1
            git branch -D $branch
        end
    end
end
