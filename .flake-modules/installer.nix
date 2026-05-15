# Builds the `nix run` installer app for all supported platforms.
#
# Usage:
#   nix run github:TheFurnace/dotfiles -- init
#     Write $XDG_CONFIG_HOME/home-manager/flake.nix (no activation).
#
#   nix run github:TheFurnace/dotfiles -- init --switch
#     Write the flake and immediately run `home-manager switch` to activate.
#
# Environment overrides (all optional):
#   DOTFILES_USER              — username  (default: $USER or `id -un`)
#   DOTFILES_HOME              — home dir  (default: $HOME)
#   DOTFILES_STATE_VERSION     — Home Manager state version (default: 25.11)
#   DOTFILES_URL               — flake URL for the dotfiles input
#                                (default: github:TheFurnace/dotfiles)
#                                Override to a local path for development:
#                                  DOTFILES_URL=/path/to/checkout nix run .#default
#   DOTFILES_NIXPKGS_URL       — flake URL for the nixpkgs input the
#                                ephemeral flake pulls in
#                                (default: github:NixOS/nixpkgs/nixos-unstable)
#   DOTFILES_HOME_MANAGER_URL  — flake URL for the home-manager input the
#                                ephemeral flake pulls in
#                                (default: git+https://github.com/nix-community/home-manager)
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
        runtimeInputs = [ pkgs.nix pkgs.git hmPackage ];
        text = ''
          # ── usage ───────────────────────────────────────────────────────────
          usage() {
            echo "Usage: nix run github:TheFurnace/dotfiles -- <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init            Write \$XDG_CONFIG_HOME/home-manager/flake.nix"
            echo "  init --switch   Write the flake and activate with home-manager switch"
          }

          # ── parse subcommand ─────────────────────────────────────────────────
          SUBCOMMAND="''${1:-}"
          shift || true

          case "$SUBCOMMAND" in
            init) ;;
            *)
              usage
              exit 1
              ;;
          esac

          # ── parse flags ──────────────────────────────────────────────────────
          DO_SWITCH=false
          for arg in "$@"; do
            case "$arg" in
              --switch) DO_SWITCH=true ;;
              *)
                echo "Unknown option: $arg"
                usage
                exit 1
                ;;
            esac
          done

          # ── resolve identity ────────────────────────────────────────────────
          DOTFILES_USER="''${DOTFILES_USER:-''${USER:-$(id -un)}}"
          DOTFILES_HOME="''${DOTFILES_HOME:-$HOME}"
          DOTFILES_STATE_VERSION="''${DOTFILES_STATE_VERSION:-25.11}"
          DOTFILES_URL="''${DOTFILES_URL:-github:TheFurnace/dotfiles}"
          DOTFILES_NIXPKGS_URL="''${DOTFILES_NIXPKGS_URL:-github:NixOS/nixpkgs/nixos-unstable}"
          DOTFILES_HOME_MANAGER_URL="''${DOTFILES_HOME_MANAGER_URL:-git+https://github.com/nix-community/home-manager}"

          # ── detect non-NixOS Linux ───────────────────────────────────────────
          # /etc/NIXOS is the canonical marker for a NixOS system.
          # targets.genericLinux.enable is only meaningful on Linux, not Darwin.
          EXTRA_MODULES_BLOCK=""
          if [ "$(uname -s)" = "Linux" ] && [ ! -e /etc/NIXOS ]; then
            EXTRA_MODULES_BLOCK=$(printf '        extraModules = [\n          { targets.genericLinux.enable = true; }\n        ];')
          fi

          echo "Installing dotfiles for user: $DOTFILES_USER"
          echo "Home directory:               $DOTFILES_HOME"
          echo "State version:                $DOTFILES_STATE_VERSION"
          echo "Dotfiles source:              $DOTFILES_URL"
          echo ""

          # ── write flake to XDG config home ──────────────────────────────────
          HM_CONFIG_DIR="''${XDG_CONFIG_HOME:-$DOTFILES_HOME/.config}/home-manager"
          mkdir -p "$HM_CONFIG_DIR"
          FLAKE_PATH="$HM_CONFIG_DIR/flake.nix"

          if [ -e "$FLAKE_PATH" ]; then
            echo "flake.nix already exists at $FLAKE_PATH — skipping write."
            echo "Delete it first if you want to regenerate."
          else
            cat > "$FLAKE_PATH" <<FLAKE
          {
            description = "Home Manager configuration for $DOTFILES_USER";

            inputs = {
              nixpkgs.url = "$DOTFILES_NIXPKGS_URL";

              home-manager = {
                url = "$DOTFILES_HOME_MANAGER_URL";
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
          $EXTRA_MODULES_BLOCK
                };
            };
          }
          FLAKE

            echo "Wrote $FLAKE_PATH"
          fi

          # ── activate (only with --switch) ────────────────────────────────────
          if $DO_SWITCH; then
            home-manager switch -b backup --flake "$HM_CONFIG_DIR#$DOTFILES_USER"
          fi
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
