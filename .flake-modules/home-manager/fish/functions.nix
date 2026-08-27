{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    programs.fish.functions = {
      bwrap-clean = {
        description = "Remove empty files left behind by failed bwrap sandbox operations";
        body = ''
          set -l search_path (pwd)
          if test (count $argv) -gt 0
              set search_path $argv[1]
          end
          set -l targets (find "$search_path" -empty -type f ! -name "*.py" ! -name "*.lock" -print0 2>/dev/null | string split0)

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
                  rm -f -- "$f"
              end
              echo "Removed "(count $targets)" file(s)."
          else
              echo "Aborted."
          end
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
}
