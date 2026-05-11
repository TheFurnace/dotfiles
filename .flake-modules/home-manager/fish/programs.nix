{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;

      shellInit = ''
        fish_add_path ~/.local/bin
      '';
    };
  };
}
