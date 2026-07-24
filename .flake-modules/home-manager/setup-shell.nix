# Installs `dotfiles-setup-shell` into the Home Manager profile: a helper
# that has this user's username/homeDirectory baked in, so finishing login
# shell setup on standalone (non-NixOS) Linux is a single `sudo` command
# instead of the longer `nix run ... -- setup-shell` compatibility path.
#
# Shares its core logic with that compatibility path via
# .flake-modules/lib/setup-shell.nix.
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;

  setupShellScript = import ../lib/setup-shell.nix {
    defaultUserExpr = cfg.username;
    defaultHomeExpr = cfg.homeDirectory;
    sudoCommand = "sudo dotfiles-setup-shell";
    initSwitchCommand = "nix run \${DOTFILES_URL:-github:TheFurnace/dotfiles} -- init --switch";
  };

  dotfilesSetupShell = pkgs.writeShellApplication {
    name = "dotfiles-setup-shell";
    text = ''
      ${setupShellScript}
      setup_shell "''${1:-}"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ dotfilesSetupShell ];
  };
}
