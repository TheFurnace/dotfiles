function dotfiles-check --description "Show which ~/.config files are dotfiles symlinks vs native"
    argparse v/verbose -- $argv

    set -l dirs fish git nvim oh-my-posh
    set -l n_managed 0
    set -l n_native 0

    for dir in $dirs
        set -l base $HOME/.config/$dir
        test -d $base; or continue

        set -l files (command find $base \( -type f -o -type l \) | sort)
        test (count $files) -gt 0; or continue

        echo
        set_color --bold; echo $dir; set_color normal

        for path in $files
            set -l rel (string replace -- "$HOME/.config/" "" $path)
            if test -L $path
                set n_managed (math $n_managed + 1)
                set_color green; printf "  ✓ dotfiles  "; set_color normal
                echo $rel
                if set -q _flag_verbose
                    set_color brblack; printf "             → %s\n" (readlink $path); set_color normal
                end
            else
                set n_native (math $n_native + 1)
                set_color yellow; printf "  · native    "; set_color normal
                echo $rel
            end
        end
    end

    echo
    set_color green; printf "%d dotfiles-managed" $n_managed; set_color normal
    printf "  "
    set_color yellow; printf "%d native\n" $n_native; set_color normal
end
