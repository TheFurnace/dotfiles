# Pi is intentionally installed outside the Nix store: its upstream installer
# manages Pi's bundled Node runtime and self-updates.  Nix owns the surrounding
# terminal dependency (tmux) and invokes the installer exactly once per user.
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.tmux ];

    home.activation.installPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x "${config.home.homeDirectory}/.local/bin/pi" ] \
        || command -v pi >/dev/null 2>&1; then
        echo "dotfiles: Pi is already installed"
      else
        echo "dotfiles: installing Pi via https://pi.dev/install.sh"
        ${pkgs.curl}/bin/curl -fsSL https://pi.dev/install.sh | ${pkgs.bash}/bin/sh
      fi
    '';
  };
}
