{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    # On non-NixOS platforms we cannot reliably change the account login shell
    # from Home Manager, so emit a one-time reminder after activation.
    home.activation.reportFishLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      fish_shell="$(command -v fish 2>/dev/null || true)"
      if [ -z "$fish_shell" ]; then
        fish_shell="${config.home.homeDirectory}/.nix-profile/bin/fish"
      fi

      current_shell="$(
        (command -v getent >/dev/null 2>&1 && getent passwd "${cfg.username}" | cut -d: -f7) || true
      )"

      if [ -n "$current_shell" ] \
        && [ "$current_shell" != "$fish_shell" ] \
        && [ "$current_shell" != "${pkgs.fish}/bin/fish" ] \
        && [ "$current_shell" != "/run/current-system/sw/bin/fish" ]; then
        echo "dotfiles: fish is installed and configured, but your login shell is still $current_shell"
        echo "dotfiles: if your platform blocks automatic shell changes, run once:"
        echo "dotfiles:   sudo nix run github:TheFurnace/dotfiles -- setup-shell fish"
      fi
    '';
  };
}
