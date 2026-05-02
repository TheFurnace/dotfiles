{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    # On non-NixOS platforms we cannot reliably change the account login shell
    # from Home Manager, so emit a one-time reminder after activation.
    home.activation.reportFishLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      current_shell="$(
        (command -v getent >/dev/null 2>&1 && getent passwd "${cfg.username}" | cut -d: -f7) || true
      )"

      if [ -n "$current_shell" ] \
        && [ "$current_shell" != "${pkgs.fish}/bin/fish" ] \
        && [ "$current_shell" != "/run/current-system/sw/bin/fish" ]; then
        echo "dotfiles: fish is installed and configured, but your login shell is still $current_shell"
        echo "dotfiles: on non-NixOS, run once: chsh -s \"$(command -v fish)\""
      fi
    '';
  };
}
