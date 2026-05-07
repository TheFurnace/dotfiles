{ nix-index-database }:
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  # nix-index-database replaces local nix-index generation, which is heavier
  # and unnecessary in this environment.
  imports = [ nix-index-database.homeModules.nix-index ];

  config = lib.mkIf cfg.enable {
    programs.nix-index-database.comma.enable = true;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableFishIntegration = true;

      config.global = {
        hide_env_diff = true;
        warn_timeout = "30s";
      };
    };

    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    programs.fish = {
      enable = true;

      shellInit = ''
        fish_add_path ~/.local/bin
      '';

      interactiveShellInit = ''
        ${pkgs.oh-my-posh}/bin/oh-my-posh init fish --config ~/.config/oh-my-posh/themes/lambda.omp.json | source
        ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
      '';

      functions = {
        bwrap-clean = {
          description = "Remove empty files left behind by failed bwrap sandbox operations";
          body = ''
            set -l search_path (pwd)
            if test (count $argv) -gt 0
                set search_path $argv[1]
            end
            set -l targets (find $search_path -empty -type f ! -name "*.py" ! -name "*.lock" 2>/dev/null)

            if test (count $targets) -eq 0
                echo "Nothing to clean."
                return 0
            end

            echo "Empty files to remove:"
            for f in $targets
                echo "  $f"
            end

            read --prompt-str "Remove these files? [y/N] " confirm
            if test "$confirm" = y -o "$confirm" = Y
                for f in $targets
                    rm -f -- $f
                end
                echo "Removed "(count $targets)" file(s)."
            else
                echo "Aborted."
            end
          '';
        };

        claude-web = {
          description = "Claude with unrestricted internet (git credentials blocked)";
          body = ''
            set -x GIT_CONFIG_PARAMETERS "'credential.helper='"
            set -x GIT_TERMINAL_PROMPT 0
            claude $argv
          '';
        };

        dotfiles-git = {
          wraps = "git";
          description = "Run git against the dotfiles repo (bare or normal-repo-with-symlinks)";
          body = ''
            # Bare repo mode: ~/.dotfiles/ is a bare git repo; work-tree is $HOME
            if test -f $HOME/.dotfiles/HEAD
                git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
                return
            end

            # Note: the previous symlink-detection fallback (for a normal repo
            # managed via mutable xdg.configFile symlinks) cannot work here because
            # programs.fish.functions embeds the body in Nix; the function file no
            # longer lives as a symlink into the dotfiles checkout. Use bare-repo
            # mode instead.
            echo "dotfiles-git: could not locate dotfiles repository" >&2
            return 1
          '';
        };

        ls = {
          wraps = "ls";
          description = "List directory contents";
          body = ''
            command ls --color=auto --group-directories-first $argv
          '';
        };
      };
    };
  };
}
