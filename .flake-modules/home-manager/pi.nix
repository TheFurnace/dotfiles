# Pi is intentionally installed outside the Nix store: its upstream installer
# manages Pi's bundled Node runtime and self-updates.  Nix owns the surrounding
# terminal dependencies (tmux, jq, and Python) and invokes the installer exactly once per
# user.
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      tmux
      jq
      python3
    ];

    home.activation.installPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      pi_binary="${config.home.homeDirectory}/.local/bin/pi"
      if [ ! -x "$pi_binary" ]; then
        # Pi's installer puts the executable under a versioned bundled-Node directory.
        for candidate in "${config.home.homeDirectory}/.local/share/pi-node/"*/bin/pi; do
          if [ -x "$candidate" ]; then
            pi_binary="$candidate"
            break
          fi
        done
      fi

      if [ -x "$pi_binary" ] || command -v pi >/dev/null 2>&1; then
        echo "dotfiles: Pi is already installed"
      else
        echo "dotfiles: installing Pi via https://pi.dev/install.sh"
        ${pkgs.curl}/bin/curl -fsSL https://pi.dev/install.sh | ${pkgs.bash}/bin/sh
      fi
    '';
  };
}
