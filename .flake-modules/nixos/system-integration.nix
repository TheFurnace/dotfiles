{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;

  # Let callers override the home path explicitly, but keep a predictable
  # default for typical systems.
  effectiveHomeDirectory =
    if cfg.homeDirectory != null then cfg.homeDirectory
    else "/home/${cfg.username}";
in
{
  config = lib.mkIf cfg.enable {
    # Ensure fish exists both as a managed package and as a valid login shell
    # from the system's perspective.
    programs.fish.enable = true;
    environment.shells = [ pkgs.fish ];

    # Fill in the user home and shell if the surrounding NixOS config did not
    # already set them more specifically.
    users.users.${cfg.username} = {
      home = lib.mkDefault effectiveHomeDirectory;
      shell = pkgs.fish;
    };
  };
}
