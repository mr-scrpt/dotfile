function mvdir
    set dest $argv[-1]
    mkdir -p (dirname "$dest")
    mv $argv
end
