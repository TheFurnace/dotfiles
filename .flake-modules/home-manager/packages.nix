{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    # Keep package installation centralized here; actual config files are
    # supplied from .config/ below.
    home.packages = with pkgs; [
      fira-code
      clang
      git
      just
      kitty
      ripgrep
      nix-your-shell
      oh-my-posh
      powershell
      gh
      tree-sitter
    ];
  };
}
