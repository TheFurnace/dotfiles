{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    programs.fish.interactiveShellInit = lib.mkAfter ''
      ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
    '';
  };
}
