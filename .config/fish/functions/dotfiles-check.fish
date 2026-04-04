function _dotfiles_check_dir --description "Recursive tree helper for dotfiles-check"
    set -l dir    $argv[1]
    set -l prefix $argv[2]

    set -l children (command find $dir -mindepth 1 -maxdepth 1 | sort)
    set -l total (count $children)

    for i in (seq $total)
        set -l path $children[$i]
        set -l name (basename $path)

        if test $i -eq $total
            printf "%s└── " $prefix
            set -l child_prefix "$prefix    "
        else
            printf "%s├── " $prefix
            set -l child_prefix "$prefix│   "
        end

        if test -L $path
            set -g _dc_managed (math $_dc_managed + 1)
            set_color green; printf "%s ✓" $name; set_color normal; echo
            if set -q _dc_verbose
                set_color brblack
                printf "%s    → %s\n" $prefix (readlink $path)
                set_color normal
            end
        else if test -d $path
            set_color --bold; echo $name; set_color normal
            _dotfiles_check_dir $path $child_prefix
        else
            set -g _dc_native (math $_dc_native + 1)
            set_color yellow; printf "%s ·" $name; set_color normal; echo
        end
    end
end

function dotfiles-check --description "Show which ~/.config files are dotfiles symlinks vs native"
    argparse v/verbose -- $argv

    set -g _dc_managed 0
    set -g _dc_native  0
    set -e _dc_verbose
    if set -q _flag_verbose
        set -g _dc_verbose 1
    end

    set -l dirs fish git nvim oh-my-posh
    set -l active_dirs
    for dir in $dirs
        test -d $HOME/.config/$dir; and set -a active_dirs $dir
    end

    set_color --bold; echo "~/.config"; set_color normal

    set -l total (count $active_dirs)
    for i in (seq $total)
        set -l dir $active_dirs[$i]
        if test $i -eq $total
            printf "└── "
            set -l child_prefix "    "
        else
            printf "├── "
            set -l child_prefix "│   "
        end
        set_color --bold; echo $dir; set_color normal
        _dotfiles_check_dir $HOME/.config/$dir $child_prefix
    end

    echo
    set_color green;  printf "%d dotfiles-managed" $_dc_managed; set_color normal
    printf "  "
    set_color yellow; printf "%d native\n"          $_dc_native;  set_color normal

    set -e _dc_managed
    set -e _dc_native
    set -e _dc_verbose
end
