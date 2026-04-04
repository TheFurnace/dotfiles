function dotfiles-save --description "Copy a ~/.config file into its dotfiles repo equivalent and stage it"
    if test (count $argv) -ne 1
        echo "Usage: dotfiles-save <path>"
        echo "  Accepts an absolute path or a path relative to ~/.config/"
        return 1
    end

    set -l dotfiles $HOME/.dotfiles

    # Accept absolute or relative-to-~/.config
    set -l src $argv[1]
    if not string match -q "/*" $src
        set src $HOME/.config/$src
    end

    if test -L $src
        echo "error: $src is already a symlink — likely already managed by dotfiles"
        return 1
    end
    if not test -f $src
        echo "error: not a regular file: $src"
        return 1
    end

    set -l rel (string replace -- "$HOME/.config/" "" $src)
    if test "$rel" = "$src"
        echo "error: path is not under ~/.config"
        return 1
    end

    set -l dst $dotfiles/.config/$rel

    mkdir -p (dirname $dst)
    cp $src $dst
    git -C $dotfiles add -f .config/$rel

    set_color green; printf "saved & staged"; set_color normal
    printf "  %s\n" $rel
    printf "run: git -C %s commit\n" $dotfiles
end
