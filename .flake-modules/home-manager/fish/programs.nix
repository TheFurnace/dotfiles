{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;
    };
  };
}
