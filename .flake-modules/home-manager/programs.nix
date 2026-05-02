{ nix-index-database }:
{ config, lib, ... }:
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

      config.global = {
        hide_env_diff = true;
        warn_timeout = "30s";
      };
    };
  };
}
