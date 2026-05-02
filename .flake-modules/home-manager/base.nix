{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.mutable || cfg.localPath != "";
        message = "dotfiles.localPath must be set when dotfiles.mutable = true.";
      }
    ];

    # Allow callers to override these explicitly, while still making the
    # module self-contained by default.
    home.username = lib.mkDefault cfg.username;
    home.homeDirectory = lib.mkDefault cfg.homeDirectory;

    # Helps downstream tools pick fish even outside NixOS.
    home.sessionVariables.SHELL = "${pkgs.fish}/bin/fish";

    # Needed so GUI apps such as kitty can resolve configured fonts.
    fonts.fontconfig.enable = true;
  };
}
