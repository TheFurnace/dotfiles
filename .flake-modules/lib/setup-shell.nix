# Shared bash implementation for adding nix-managed fish/bash/pwsh binaries to
# /etc/shells and chsh-ing a user to one of them.
#
# Standalone (non-NixOS) Linux only lets root edit /etc/shells and change
# another account's login shell, so every caller of this logic must run as
# root. Two call sites share it:
#
#   - `sudo nix run github:TheFurnace/dotfiles -- setup-shell <shell>`
#     (.flake-modules/installer.nix) — a compatibility path that can target
#     any account, resolving the user/home dynamically via $SUDO_USER/getent.
#
#   - `sudo dotfiles-setup-shell <shell>` (.flake-modules/home-manager/setup-shell.nix)
#     — the preferred helper, installed into the Home Manager profile with
#     the configured user's username/homeDirectory baked in as defaults.
#
# Returns the bash source (as a string) defining `add_shell_to_list` and
# `setup_shell`; callers embed it into a `pkgs.writeShellApplication` `text`
# and invoke `setup_shell "$1"` themselves.
{
  # Bash expression (already valid bash, e.g. "alice" or "''${SUDO_USER:-}")
  # used as the fallback for DOTFILES_USER when it isn't set in the
  # environment.
  defaultUserExpr,

  # Bash expression used as the fallback for DOTFILES_HOME when it isn't set
  # in the environment and DOTFILES_USER resolved from defaultUserExpr. Pass
  # "" to skip straight to the getent lookup below (used by the installer,
  # which can target arbitrary accounts).
  defaultHomeExpr,

  # Bash text shown in the "must be run with sudo" hint, without the trailing
  # shell name, e.g. "sudo dotfiles-setup-shell" or
  # "sudo nix run \$DOTFILES_URL -- setup-shell".
  sudoCommand,

  # Bash text shown when the requested shell isn't in the target user's nix
  # profile yet, e.g. "nix run github:TheFurnace/dotfiles -- init --switch".
  initSwitchCommand,
}:
''
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

  setup_shell() {
    local requested_shell="$1"
    local shells_file target_user target_home shell_name shell_path chsh_bin candidate

    case "$requested_shell" in
      # Supported shells — fall through to the checks below.
      fish | bash | pwsh) ;;
      "")
        echo "dotfiles: setup-shell requires a shell name: fish, bash, or pwsh."
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
      echo "  ${sudoCommand} $requested_shell"
      exit 1
    fi

    # defaultUserExpr/defaultHomeExpr below are Nix parameters substituted at
    # evaluation time into this bash source, not shell variables expanded at
    # runtime — the two single quotes in the ''${ sequence below escape the
    # bash parameter-expansion syntax from Nix's own string interpolation so
    # it survives into the generated script.
    target_user="''${DOTFILES_USER:-${defaultUserExpr}}"
    if [ -z "$target_user" ]; then
      echo "dotfiles: could not determine the target user. Set DOTFILES_USER, e.g.:"
      echo "  sudo DOTFILES_USER=<user> ${sudoCommand} $requested_shell"
      exit 1
    fi

    target_home="''${DOTFILES_HOME:-${defaultHomeExpr}}"
    if [ -z "$target_home" ] && command -v getent >/dev/null 2>&1; then
      target_home="$(getent passwd "$target_user" | cut -d: -f6)" || true
      if [ -z "$target_home" ]; then
        echo "dotfiles: getent found no passwd entry for $target_user."
      fi
    fi
    if [ -z "$target_home" ]; then
      echo "dotfiles: could not determine the home directory for $target_user."
      echo "dotfiles: set DOTFILES_HOME explicitly and try again."
      exit 1
    fi

    shells_file="''${DOTFILES_SHELLS_FILE:-/etc/shells}"
    [ -e "$shells_file" ] || touch "$shells_file"

    # Register every nix-managed shell that's actually installed for this
    # user (not just the requested one), matching the promised behavior of
    # adding fish/bash/pwsh nix paths to /etc/shells in a single run.
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
      echo "dotfiles: run '${initSwitchCommand}' as $target_user first."
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
''
