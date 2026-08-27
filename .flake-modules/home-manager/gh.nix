{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf (cfg.enable && cfg.features.development.enable) {
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };
  };
}
