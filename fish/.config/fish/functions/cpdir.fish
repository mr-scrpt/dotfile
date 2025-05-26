function cpdir
    set dest $argv[-1]
    mkdir -p (dirname "$dest")
    cp -Ri $argv
end
