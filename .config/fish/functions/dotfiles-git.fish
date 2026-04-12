function dotfiles-git --wraps=git --description 'Run git against the dotfiles repo (bare or normal-repo-with-symlinks)'
    # --- Bare repo mode ---
    # ~/.dotfiles/ is a bare git repo; work-tree is $HOME
    if test -f $HOME/.dotfiles/HEAD
        git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
        return
    end

    # --- Normal repo mode ---
    # This file is a symlink:  ~/.config/fish/functions/dotfiles-git.fish
    #                    → ... /<repo>/.config/fish/functions/dotfiles-git.fish
    # Follow the symlink and climb four directories to reach the repo root.
    set -l this_file (status current-filename)
    if test -L $this_file
        set -l real (realpath $this_file)
        # real: <repo>/.config/fish/functions/dotfiles-git.fish
        #  up1: <repo>/.config/fish/functions/
        #  up2: <repo>/.config/fish/
        #  up3: <repo>/.config/
        #  up4: <repo>/
        set -l repo_root (path dirname (path dirname (path dirname (path dirname $real))))
        if test -d $repo_root/.git
            git -C $repo_root $argv
            return
        end
    end

    echo "dotfiles-git: could not locate dotfiles repository" >&2
    return 1
end
