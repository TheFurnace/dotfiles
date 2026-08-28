{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    # Keep package installation centralized here; actual config files are
    # supplied from .config/ below.
    home.packages = with pkgs; [
      git
      ripgrep
      nix-your-shell
      oh-my-posh
    ] ++ lib.optionals cfg.features.development.enable [
      clang
      powershell
      gh
      tree-sitter
      roslyn-ls
      python3
    ] ++ lib.optionals cfg.features.desktop.enable [
      fira-code
      kitty
    ];
  };
}
