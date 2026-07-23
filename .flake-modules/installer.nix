# Builds the `nix run` installer app for all supported platforms.
#
# Usage:
#   nix run github:TheFurnace/dotfiles -- init
#     Write $XDG_CONFIG_HOME/home-manager/flake.nix (no activation).
#
#   nix run github:TheFurnace/dotfiles -- init --switch
#     Write the flake and immediately run `home-manager switch` to activate.
#
#   sudo nix run github:TheFurnace/dotfiles -- setup-shell <fish|bash|pwsh>
#     Add fish/bash/pwsh from the target user's nix profile to /etc/shells
#     and chsh the target user to <shell>. Standalone (non-NixOS) Linux
#     requires root for both of those, so this is a separate, sudo-only
#     subcommand; `init --switch` prints this command as a final hint when
#     the user's login shell isn't fish yet.
#
# Environment overrides (all optional):
#   DOTFILES_USER              — username  (default: $USER or `id -un`;
#                                for setup-shell: $SUDO_USER)
#   DOTFILES_HOME              — home dir  (default: $HOME;
#                                for setup-shell: looked up via getent)
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
            echo "                  child commands, and activate with home-manager switch"
            echo ""
            echo "  setup-shell <fish|bash|pwsh>"
            echo "                  Must be run with sudo. Adds the fish/bash/pwsh"
            echo "                  binaries from the target user's nix profile to"
            echo "                  /etc/shells, then runs chsh to make <shell> the"
            echo "                  target user's login shell. Intended for standalone"
            echo "                  (non-NixOS) Linux, where only root can edit"
            echo "                  /etc/shells and change another user's login shell."
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

          add_shell_to_list() {
            local shell_path="$1"
            local shells_file="$2"
            local last_char

            if grep -Fqx "$shell_path" "$shells_file" 2>/dev/null; then
              return 0
            fi

            last_char="$(tail -c 1 "$shells_file" 2>/dev/null || true)"
            if [ -n "$last_char" ]; then
              printf '\n' >> "$shells_file"
            fi
            printf '%s\n' "$shell_path" >> "$shells_file"
            echo "dotfiles: added $shell_path to $shells_file"
          }

          # ── setup-shell (run with sudo) ──────────────────────────────────────
          # Adds fish/bash/pwsh from the target user's nix profile to
          # /etc/shells, then chsh's the target user to the requested shell.
          # Standalone (non-NixOS) Linux does not let an unprivileged user edit
          # /etc/shells or change another account's login shell, so this is
          # split out from `init` and must be run with sudo.
          setup_shell() {
            local requested_shell="$1"
            local shells_file target_user target_home shell_name shell_path chsh_bin candidate

            case "$requested_shell" in
              # Supported shells — fall through to the checks below.
              fish | bash | pwsh) ;;
              "")
                echo "dotfiles: setup-shell requires a shell name: fish, bash, or pwsh."
                usage
                exit 1
                ;;
              *)
                echo "dotfiles: unsupported shell '$requested_shell'. Supported: fish, bash, pwsh."
                exit 1
                ;;
            esac

            if [ "$(id -u)" -ne 0 ]; then
              echo "dotfiles: setup-shell must be run with sudo (it edits /etc/shells and"
              echo "dotfiles: changes another account's login shell). Try:"
              echo "  sudo nix run $DOTFILES_URL -- setup-shell $requested_shell"
              exit 1
            fi

            target_user="''${DOTFILES_USER:-''${SUDO_USER:-}}"
            if [ -z "$target_user" ]; then
              echo "dotfiles: could not determine the target user. Set DOTFILES_USER, e.g.:"
              echo "  sudo DOTFILES_USER=<user> nix run $DOTFILES_URL -- setup-shell $requested_shell"
              exit 1
            fi

            target_home="''${DOTFILES_HOME:-}"
            if [ -z "$target_home" ] && command -v getent >/dev/null 2>&1; then
              # getent may legitimately find no entry (or not exist at all on
              # some minimal systems); fall back to requiring DOTFILES_HOME.
              target_home="$(getent passwd "$target_user" | cut -d: -f6 || true)"
            fi
            if [ -z "$target_home" ]; then
              echo "dotfiles: could not determine the home directory for $target_user."
              echo "dotfiles: set DOTFILES_HOME explicitly and try again."
              exit 1
            fi

            shells_file="''${DOTFILES_SHELLS_FILE:-/etc/shells}"
            [ -e "$shells_file" ] || touch "$shells_file"

            shell_path=""
            for shell_name in fish bash pwsh; do
              candidate="$target_home/.nix-profile/bin/$shell_name"
              if [ -x "$candidate" ]; then
                add_shell_to_list "$candidate" "$shells_file"
                if [ "$shell_name" = "$requested_shell" ]; then
                  shell_path="$candidate"
                fi
              fi
            done

            if [ -z "$shell_path" ]; then
              echo "dotfiles: $requested_shell was not found in $target_user's nix profile"
              echo "dotfiles: ($target_home/.nix-profile/bin/$requested_shell)."
              echo "dotfiles: run 'nix run $DOTFILES_URL -- init --switch' as $target_user first."
              exit 1
            fi

            chsh_bin="''${DOTFILES_CHSH:-$(command -v chsh 2>/dev/null || true)}"
            if [ -z "$chsh_bin" ]; then
              echo "dotfiles: added shells to $shells_file, but 'chsh' is not available."
              echo "dotfiles: use your distro's preferred shell-change command to set:"
              echo "  $shell_path"
              exit 1
            fi

            if "$chsh_bin" -s "$shell_path" "$target_user"; then
              echo "dotfiles: login shell for $target_user set to $shell_path"
            else
              echo "dotfiles: failed to set $target_user's login shell to $shell_path."
              exit 1
            fi
          }

          report_login_shell_status() {
            local current_shell fish_shell

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

            echo ""
            echo "dotfiles: your login shell is not yet fish."
            echo "dotfiles: standalone (non-NixOS) Linux requires root to add nix-managed"
            echo "dotfiles: shells to /etc/shells and change another account's login shell."
            echo "dotfiles: to finish setup, run:"
            echo "  sudo nix run $DOTFILES_URL -- setup-shell fish"
            echo "dotfiles: (fish, bash, and pwsh are all supported; swap 'fish' above"
            echo "dotfiles: for the shell you want as your login shell)."
          }

          # ── parse subcommand ─────────────────────────────────────────────────
          SUBCOMMAND="''${1:-}"
          shift || true

          # DOTFILES_URL is used by both subcommands (init writes it into the
          # generated flake; setup-shell echoes it back in its own usage/error
          # messages), so resolve it up front.
          DOTFILES_URL="''${DOTFILES_URL:-github:TheFurnace/dotfiles}"

          case "$SUBCOMMAND" in
            init) ;;
            setup-shell)
              setup_shell "''${1:-}"
              exit 0
              ;;
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
            report_login_shell_status
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
