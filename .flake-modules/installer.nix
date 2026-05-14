# Builds the `nix run` installer app for all supported platforms.
#
# Usage:
#   nix run github:TheFurnace/dotfiles
#
# Environment overrides (all optional):
#   DOTFILES_USER          — username  (default: $USER or `id -un`)
#   DOTFILES_HOME          — home dir  (default: $HOME)
#   DOTFILES_STATE_VERSION — Home Manager state version (default: 25.11)
#   DOTFILES_URL           — flake URL for the dotfiles input
#                            (default: github:TheFurnace/dotfiles)
#                            Override to a local path for development:
#                              DOTFILES_URL=/path/to/checkout nix run .#default
{ nixpkgs, home-manager, self }:
let
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  mkApp = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};

      # home-manager CLI from the locked input so it matches what the
      # generated configuration will use.
      hmPackage = home-manager.packages.${system}.home-manager;

      installer = pkgs.writeShellApplication {
        name = "install-dotfiles";
        runtimeInputs = [ pkgs.nix hmPackage ];
        text = ''
          # ── resolve identity ────────────────────────────────────────────────
          DOTFILES_USER="''${DOTFILES_USER:-''${USER:-$(id -un)}}"
          DOTFILES_HOME="''${DOTFILES_HOME:-$HOME}"
          DOTFILES_STATE_VERSION="''${DOTFILES_STATE_VERSION:-25.11}"
          DOTFILES_URL="''${DOTFILES_URL:-github:TheFurnace/dotfiles}"

          echo "Installing dotfiles for user: $DOTFILES_USER"
          echo "Home directory:               $DOTFILES_HOME"
          echo "State version:                $DOTFILES_STATE_VERSION"
          echo "Dotfiles source:              $DOTFILES_URL"
          echo ""

          # ── write an ephemeral flake that wires the dotfiles module ─────────
          WORK_DIR="$(mktemp -d)"
          trap 'rm -rf "$WORK_DIR"' EXIT

          cat > "$WORK_DIR/flake.nix" <<FLAKE
          {
            description = "Ephemeral dotfiles installer";

            inputs = {
              nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

              home-manager = {
                url = "git+https://github.com/nix-community/home-manager";
                inputs.nixpkgs.follows = "nixpkgs";
              };

              dotfiles = {
                url = "$DOTFILES_URL";
                inputs.nixpkgs.follows = "nixpkgs";
              };
            };

            outputs = { dotfiles, ... }: {
              homeConfigurations."$DOTFILES_USER" =
                dotfiles.lib.mkHomeConfiguration {
                  username      = "$DOTFILES_USER";
                  homeDirectory = "$DOTFILES_HOME";
                  stateVersion  = "$DOTFILES_STATE_VERSION";
                };
            };
          }
          FLAKE

          # ── activate ────────────────────────────────────────────────────────
          home-manager switch -b backup --flake "$WORK_DIR#$DOTFILES_USER"
        '';
      };
    in
    {
      type = "app";
      program = "${installer}/bin/install-dotfiles";
    };

  appsForSystem = system: { default = mkApp system; };
in
{
  apps = builtins.listToAttrs (map
    (system: { name = system; value = appsForSystem system; })
    systems);
}
