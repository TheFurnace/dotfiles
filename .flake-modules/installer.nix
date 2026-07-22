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
#   DOTFILES_NIXPKGS_URL       — optional nixpkgs flake URL override.
#                                When unset, the generated flake follows
#                                dotfiles/nixpkgs (pinned by dotfiles.lock).
#   DOTFILES_HOME_MANAGER_URL  — optional home-manager flake URL override.
#                                When unset, the generated flake follows
#                                dotfiles/home-manager (pinned by dotfiles.lock).
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
            echo "                  and ensure \$XDG_CONFIG_HOME/nix/nix.conf enables"
            echo "                  experimental-features = nix-command flakes"
            echo "  init --switch   Write the flake, ensure user-level flake support for"
            echo "                  child commands, activate with home-manager switch,"
            echo "                  and on standalone Linux try to set fish as the"
            echo "                  login shell when the platform allows it"
            echo ""
            echo "Note: the initial 'nix run ...' command must already be able to"
            echo "parse flakes before this installer starts."
          }

          ensure_nix_experimental_features() {
            local xdg_config_home nix_config_dir nix_conf_path existing_features
            local merged_features tmp_conf

            xdg_config_home="''${XDG_CONFIG_HOME:-$DOTFILES_HOME/.config}"
            nix_config_dir="$xdg_config_home/nix"
            nix_conf_path="$nix_config_dir/nix.conf"

            mkdir -p "$nix_config_dir"

            existing_features=""
            if [ -f "$nix_conf_path" ]; then
              existing_features="$(
                awk '
                  /^[[:space:]]*experimental-features[[:space:]]*=/ {
                    line = $0
                    sub(/^[^=]*=[[:space:]]*/, "", line)
                    sub(/[[:space:]]*#.*/, "", line)
                    print line
                  }
                ' "$nix_conf_path" \
                  | tr ' \t' '\n' \
                  | sed '/^$/d'
              )"
            fi

            merged_features="$(
              {
                if [ -n "$existing_features" ]; then
                  printf '%s\n' "$existing_features"
                fi
                printf '%s\n' nix-command flakes
              } \
                | tr ' ' '\n' \
                | sed '/^$/d' \
                | awk '!seen[$0]++' \
                | paste -sd' ' -
            )"

            tmp_conf="$(mktemp)"

            if [ -f "$nix_conf_path" ]; then
              awk -v features="$merged_features" '
                BEGIN { written = 0 }
                /^[[:space:]]*experimental-features[[:space:]]*=/ {
                  if (!written) {
                    print "experimental-features = " features
                    written = 1
                  }
                  next
                }
                { print }
                END {
                  if (!written) {
                    print "experimental-features = " features
                  }
                }
              ' "$nix_conf_path" > "$tmp_conf"
            else
              printf 'experimental-features = %s\n' "$merged_features" > "$tmp_conf"
            fi

            if [ ! -f "$nix_conf_path" ] || ! cmp -s "$tmp_conf" "$nix_conf_path"; then
              mv "$tmp_conf" "$nix_conf_path"
              echo "Ensured $nix_conf_path enables experimental-features = $merged_features"
            else
              rm -f "$tmp_conf"
              echo "$nix_conf_path already enables experimental-features = $merged_features"
            fi

            if [ -n "''${NIX_USER_CONF_FILES:-}" ]; then
              export NIX_USER_CONF_FILES="$nix_conf_path:$NIX_USER_CONF_FILES"
            else
              export NIX_USER_CONF_FILES="$nix_conf_path"
            fi

            if [ -n "''${NIX_CONFIG:-}" ]; then
              export NIX_CONFIG="experimental-features = $merged_features
$NIX_CONFIG"
            else
              export NIX_CONFIG="experimental-features = $merged_features"
            fi
          }

          current_login_shell() {
            if command -v getent >/dev/null 2>&1; then
              getent passwd "$DOTFILES_USER" | cut -d: -f7
            elif [ -r /etc/passwd ]; then
              awk -F: -v user="$DOTFILES_USER" '$1 == user { print $7; exit }' /etc/passwd
            fi
          }

          ensure_shell_is_accepted() {
            local fish_shell="$1"
            local shells_file="$2"
            local last_char

            if [ ! -e "$shells_file" ]; then
              echo "dotfiles: fish is installed at $fish_shell, but $shells_file does not exist."
              echo "dotfiles: add this path with appropriate privileges, then run:"
              echo "  chsh -s \"$fish_shell\""
              return 1
            fi

            if grep -Fqx "$fish_shell" "$shells_file"; then
              return 0
            fi

            if [ ! -w "$shells_file" ]; then
              echo "dotfiles: fish is installed at $fish_shell, but $shells_file does not list it."
              echo "dotfiles: add this line with appropriate privileges, then run:"
              echo "  chsh -s \"$fish_shell\""
              return 1
            fi

            last_char="$(tail -c 1 "$shells_file" 2>/dev/null || true)"
            if [ -n "$last_char" ]; then
              printf '\n' >> "$shells_file"
            fi
            printf '%s\n' "$fish_shell" >> "$shells_file"
            echo "dotfiles: added $fish_shell to $shells_file"
          }

          maybe_configure_login_shell() {
            local current_shell fish_shell shells_file chsh_bin

            if [ "$(uname -s)" != "Linux" ]; then
              return 0
            fi

            if [ -e /etc/NIXOS ] && [ "''${DOTFILES_FORCE_LOGIN_SHELL_SETUP:-0}" != "1" ]; then
              return 0
            fi

            current_shell="$(current_login_shell || true)"
            fish_shell="$DOTFILES_HOME/.nix-profile/bin/fish"

            if [ ! -x "$fish_shell" ]; then
              fish_shell="$(command -v fish 2>/dev/null || true)"
            fi

            if [ -z "$fish_shell" ] || [ ! -x "$fish_shell" ]; then
              echo "dotfiles: fish was not found after activation, so login-shell setup was skipped."
              return 0
            fi

            if [ "$current_shell" = "$fish_shell" ]; then
              echo "dotfiles: login shell already set to $fish_shell"
              return 0
            fi

            shells_file="''${DOTFILES_SHELLS_FILE:-/etc/shells}"
            if ! ensure_shell_is_accepted "$fish_shell" "$shells_file"; then
              return 0
            fi

            chsh_bin="''${DOTFILES_CHSH:-$(command -v chsh 2>/dev/null || true)}"
            if [ -z "$chsh_bin" ]; then
              echo "dotfiles: fish is installed at $fish_shell, but 'chsh' is not available."
              echo "dotfiles: run once with your distro's preferred shell-change command."
              return 0
            fi

            if "$chsh_bin" -s "$fish_shell" "$DOTFILES_USER" </dev/null 2>/dev/null \
              || "$chsh_bin" -s "$fish_shell" </dev/null; then
              echo "dotfiles: login shell set to $fish_shell"
            else
              echo "dotfiles: fish is installed at $fish_shell, but automatic login-shell setup could not complete."
              echo "dotfiles: run once yourself (it may prompt for your account password):"
              echo "  chsh -s \"$fish_shell\""
            fi
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
          DOTFILES_NIXPKGS_URL="''${DOTFILES_NIXPKGS_URL:-}"
          DOTFILES_HOME_MANAGER_URL="''${DOTFILES_HOME_MANAGER_URL:-}"

          ensure_nix_experimental_features

          # By default, reuse the dotfiles input lock for nixpkgs and
          # home-manager. Callers can override either input explicitly.
          NIXPKGS_INPUT_BLOCK='nixpkgs.follows = "dotfiles/nixpkgs";'
          DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK=""
          if [ -n "$DOTFILES_NIXPKGS_URL" ]; then
            NIXPKGS_INPUT_BLOCK=$(printf 'nixpkgs.url = "%s";' "$DOTFILES_NIXPKGS_URL")
            DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK='inputs.nixpkgs.follows = "nixpkgs";'
          fi

          HOME_MANAGER_INPUT_BLOCK='home-manager.follows = "dotfiles/home-manager";'
          DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK=""
          if [ -n "$DOTFILES_HOME_MANAGER_URL" ]; then
            HOME_MANAGER_INPUT_BLOCK="$(
              printf '%s\n' \
                'home-manager = {' \
                "  url = \"$DOTFILES_HOME_MANAGER_URL\";" \
                '  inputs.nixpkgs.follows = "nixpkgs";' \
                '};'
            )"
            DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK='inputs.home-manager.follows = "home-manager";'
          fi

          # ── detect non-NixOS Linux ───────────────────────────────────────────
          # /etc/NIXOS is the canonical marker for a NixOS system.
          # targets.genericLinux.enable is only meaningful on Linux, not Darwin.
          EXTRA_MODULES_BLOCK=""
          if [ "$(uname -s)" = "Linux" ] && [ ! -e /etc/NIXOS ]; then
            EXTRA_MODULES_BLOCK="$(
              printf '%s\n' \
                'extraModules = [' \
                '  { targets.genericLinux.enable = true; }' \
                '];'
            )"
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
            {
              printf '%s\n' '{'
              printf '%s\n' "  description = \"Home Manager configuration for $DOTFILES_USER\";"
              printf '\n'
              printf '%s\n' '  inputs = {'
              printf '    %s\n' "$NIXPKGS_INPUT_BLOCK"
              printf '\n'
              printf '%s\n' "$HOME_MANAGER_INPUT_BLOCK" | sed 's/^/    /'
              printf '\n'
              printf '%s\n' '    dotfiles = {'
              printf '%s\n' "      url = \"$DOTFILES_URL\";"
              if [ -n "$DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK" ]; then
                printf '      %s\n' "$DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK"
              fi
              if [ -n "$DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK" ]; then
                printf '      %s\n' "$DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK"
              fi
              printf '%s\n' '    };'
              printf '%s\n' '  };'
              printf '\n'
              printf '%s\n' '  outputs = { dotfiles, ... }: {'
              printf '%s\n' "    homeConfigurations.\"$DOTFILES_USER\" ="
              printf '%s\n' '      dotfiles.lib.mkHomeConfiguration {'
              printf '%s\n' "        username      = \"$DOTFILES_USER\";"
              printf '%s\n' "        homeDirectory = \"$DOTFILES_HOME\";"
              printf '%s\n' "        stateVersion  = \"$DOTFILES_STATE_VERSION\";"
              if [ -n "$EXTRA_MODULES_BLOCK" ]; then
                printf '%s\n' "$EXTRA_MODULES_BLOCK" | sed 's/^/        /'
              fi
              printf '%s\n' '      };'
              printf '%s\n' '  };'
              printf '%s\n' '}'
            } > "$FLAKE_PATH"

            echo "Wrote $FLAKE_PATH"
          fi

          # ── activate (only with --switch) ────────────────────────────────────
          if $DO_SWITCH; then
            home-manager switch -b backup --flake "$HM_CONFIG_DIR#$DOTFILES_USER"
            maybe_configure_login_shell
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
