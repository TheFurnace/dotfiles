{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        function __update_cwd_osc --on-event fish_prompt
            printf '\e]9;9;%s\a' "$PWD"
        end
      '';
    };
  };
}
