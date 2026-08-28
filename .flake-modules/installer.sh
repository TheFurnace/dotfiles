#!/usr/bin/env bash

set -euo pipefail

DOTFILES_URL="${DOTFILES_URL:-github:TheFurnace/dotfiles}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  bold=$'\033[1m'
  blue=$'\033[34m'
  green=$'\033[32m'
  yellow=$'\033[33m'
  reset=$'\033[0m'
else
  bold=""
  blue=""
  green=""
  yellow=""
  reset=""
fi

usage() {
  cat <<'EOF'
Usage: nix run github:TheFurnace/dotfiles [-- options]

Run without options for the interactive installer.

Options:
  --unattended    Install and activate using detected values and environment
                  overrides, without prompting
  --with-ai       Install Pi and Codex from their upstream installers after
                  Home Manager activation
  -h, --help      Show this help

Compatibility command:
  setup-shell <fish|bash|pwsh>
                  Run with sudo to select a nix-managed login shell on
                  standalone Linux

Environment overrides:
  DOTFILES_USER, DOTFILES_HOME, DOTFILES_STATE_VERSION, DOTFILES_URL,
  DOTFILES_NIXPKGS_URL, DOTFILES_HOME_MANAGER_URL
EOF
}

say() {
  printf '%b==>%b %s\n' "$blue$bold" "$reset" "$*"
}

success() {
  printf '%b✓%b %s\n' "$green$bold" "$reset" "$*"
}

note() {
  printf '%b!%b %s\n' "$yellow$bold" "$reset" "$*"
}

prompt_value() {
  local label=$1
  local default_value=$2
  local value

  printf '%s [%s]: ' "$label" "$default_value" >/dev/tty
  IFS= read -r value </dev/tty
  printf '%s' "${value:-$default_value}"
}

prompt_yes_no() {
  local label=$1
  local default_value=$2
  local hint reply

  if [[ $default_value == true ]]; then
    hint="Y/n"
  else
    hint="y/N"
  fi

  while true; do
    printf '%s [%s]: ' "$label" "$hint" >/dev/tty
    IFS= read -r reply </dev/tty
    case ${reply,,} in
      "") printf '%s\n' "$default_value"; return ;;
      y|yes) printf 'true\n'; return ;;
      n|no) printf 'false\n'; return ;;
      *) printf 'Please answer yes or no.\n' >/dev/tty ;;
    esac
  done
}

nix_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//\$\{/\\\$\{}
  printf '%s' "$value"
}

ensure_nix_experimental_features() {
  local xdg_config_home nix_config_dir nix_conf_path existing_features
  local merged_features tmp_conf

  xdg_config_home="${XDG_CONFIG_HOME:-$DOTFILES_HOME/.config}"
  nix_config_dir="$xdg_config_home/nix"
  nix_conf_path="$nix_config_dir/nix.conf"
  mkdir -p "$nix_config_dir"

  existing_features=""
  if [[ -f $nix_conf_path ]]; then
    existing_features="$(
      awk '
        /^[[:space:]]*experimental-features[[:space:]]*=/ {
          line = $0
          sub(/^[^=]*=[[:space:]]*/, "", line)
          sub(/[[:space:]]*#.*/, "", line)
          print line
        }
      ' "$nix_conf_path" | tr ' \t' '\n' | sed '/^$/d'
    )"
  fi

  merged_features="$(
    {
      [[ -z $existing_features ]] || printf '%s\n' "$existing_features"
      printf '%s\n' nix-command flakes
    } | tr ' ' '\n' | sed '/^$/d' | awk '!seen[$0]++' | paste -sd' ' -
  )"

  tmp_conf=$(mktemp)
  if [[ -f $nix_conf_path ]]; then
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
        if (!written) print "experimental-features = " features
      }
    ' "$nix_conf_path" >"$tmp_conf"
  else
    printf 'experimental-features = %s\n' "$merged_features" >"$tmp_conf"
  fi

  if [[ ! -f $nix_conf_path ]] || ! cmp -s "$tmp_conf" "$nix_conf_path"; then
    mv "$tmp_conf" "$nix_conf_path"
    success "Enabled flakes in $nix_conf_path"
  else
    rm -f "$tmp_conf"
  fi

  if [[ -n ${NIX_USER_CONF_FILES:-} ]]; then
    export NIX_USER_CONF_FILES="$nix_conf_path:$NIX_USER_CONF_FILES"
  else
    export NIX_USER_CONF_FILES="$nix_conf_path"
  fi

  if [[ -n ${NIX_CONFIG:-} ]]; then
    export NIX_CONFIG="experimental-features = $merged_features
$NIX_CONFIG"
  else
    export NIX_CONFIG="experimental-features = $merged_features"
  fi
}

current_login_shell() {
  if command -v getent >/dev/null 2>&1; then
    getent passwd "$DOTFILES_USER" | cut -d: -f7
  elif [[ -r /etc/passwd ]]; then
    awk -F: -v user="$DOTFILES_USER" '$1 == user { print $7; exit }' /etc/passwd
  fi
}

report_login_shell_status() {
  local current_shell fish_shell

  [[ $(uname -s) == Linux ]] || return 0
  if [[ -e /etc/NIXOS && ${DOTFILES_FORCE_LOGIN_SHELL_SETUP:-0} != 1 ]]; then
    return 0
  fi

  current_shell=$(current_login_shell || true)
  fish_shell="$DOTFILES_HOME/.nix-profile/bin/fish"
  if [[ ! -x $fish_shell ]]; then
    fish_shell=$(command -v fish 2>/dev/null || true)
  fi

  if [[ -z $fish_shell || ! -x $fish_shell ]]; then
    note "Fish was not found after activation; login-shell setup was skipped."
  elif [[ $current_shell == "$fish_shell" ]]; then
    success "Your login shell is already $fish_shell"
  else
    printf '\n'
    note "Your login shell is not yet Fish. To change it, run:"
    printf '  sudo %s/.nix-profile/bin/dotfiles-setup-shell fish\n' "$DOTFILES_HOME"
  fi
}

UNATTENDED=false
INSTALL_AI=false

if [[ ${1:-} == setup-shell ]]; then
  shift
  setup_shell "${1:-}"
  exit 0
fi

# Resolve install identity only after dispatching setup-shell. Under sudo, the
# compatibility command must be able to fall back to SUDO_USER rather than
# inheriting root's USER and HOME from the installer process.
DOTFILES_USER="${DOTFILES_USER:-${USER:-$(id -un)}}"
DOTFILES_HOME="${DOTFILES_HOME:-$HOME}"
DOTFILES_STATE_VERSION="${DOTFILES_STATE_VERSION:-25.11}"
DOTFILES_NIXPKGS_URL="${DOTFILES_NIXPKGS_URL:-}"
DOTFILES_HOME_MANAGER_URL="${DOTFILES_HOME_MANAGER_URL:-}"

while (($#)); do
  case $1 in
    --unattended) UNATTENDED=true ;;
    --with-ai) INSTALL_AI=true ;;
    -h|--help) usage; exit 0 ;;
    init)
      printf "The 'init' command has been replaced by the interactive installer.\n" >&2
      printf "Run 'nix run %s' instead.\n" "$DOTFILES_URL" >&2
      exit 2
      ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if ! $UNATTENDED && [[ ! -t 0 && ! -t 1 && ! -t 2 ]]; then
  printf 'The interactive installer needs a terminal.\n' >&2
  printf 'For automation, pass --unattended.\n' >&2
  exit 1
fi

printf '\n%bTheFurnace dotfiles%b\n' "$bold" "$reset"
printf 'A small, opinionated Linux environment powered by Nix.\n\n'

if ! $UNATTENDED; then
  DOTFILES_USER=$(prompt_value "Username" "$DOTFILES_USER")
  DOTFILES_HOME=$(prompt_value "Home directory" "$DOTFILES_HOME")
  DOTFILES_STATE_VERSION=$(prompt_value "Home Manager state version" "$DOTFILES_STATE_VERSION")
  if ! $INSTALL_AI; then
    INSTALL_AI=$(prompt_yes_no "Install the mutable Pi and Codex CLIs after activation" false)
  fi
fi

if [[ -z $DOTFILES_USER ]]; then
  printf 'Username cannot be empty.\n' >&2
  exit 1
fi
if [[ $DOTFILES_HOME != /* ]]; then
  printf 'Home directory must be an absolute path: %s\n' "$DOTFILES_HOME" >&2
  exit 1
fi
if [[ ! $DOTFILES_STATE_VERSION =~ ^[0-9]{2}\.[0-9]{2}$ ]]; then
  printf 'Home Manager state version must look like 25.11: %s\n' "$DOTFILES_STATE_VERSION" >&2
  exit 1
fi

HM_CONFIG_DIR="${XDG_CONFIG_HOME:-$DOTFILES_HOME/.config}/home-manager"
FLAKE_PATH="$HM_CONFIG_DIR/flake.nix"
REPLACE_EXISTING=false
FLAKE_IS_MANAGED=false

if [[ -f $FLAKE_PATH ]] && grep -Fqx '# Generated by TheFurnace/dotfiles installer.' "$FLAKE_PATH"; then
  FLAKE_IS_MANAGED=true
elif [[ -e $FLAKE_PATH || -L $FLAKE_PATH ]]; then
  if $UNATTENDED; then
    printf 'Refusing to replace an unmanaged Home Manager flake: %s\n' "$FLAKE_PATH" >&2
    exit 1
  fi
  note "A Home Manager flake already exists at $FLAKE_PATH"
  REPLACE_EXISTING=$(prompt_yes_no "Back it up and replace it" false)
  if ! $REPLACE_EXISTING; then
    printf 'Installation cancelled; no files were changed.\n'
    exit 0
  fi
fi

printf '%bInstallation plan%b\n' "$bold" "$reset"
printf '  User          %s\n' "$DOTFILES_USER"
printf '  Home          %s\n' "$DOTFILES_HOME"
printf '  Platform      %s\n' "$DOTFILES_INSTALLER_SYSTEM"
printf '  State version %s\n' "$DOTFILES_STATE_VERSION"
printf '  Configuration %s\n' "$FLAKE_PATH"
printf '  Pi + Codex    %s\n' "$INSTALL_AI"
printf '\n'

if ! $UNATTENDED && [[ $(prompt_yes_no "Install and activate now" true) != true ]]; then
  printf 'Installation cancelled; no files were changed.\n'
  exit 0
fi

say "Preparing Nix"
ensure_nix_experimental_features

NIXPKGS_INPUT_BLOCK='nixpkgs.follows = "dotfiles/nixpkgs";'
DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK=""
if [[ -n $DOTFILES_NIXPKGS_URL ]]; then
  NIXPKGS_INPUT_BLOCK="nixpkgs.url = \"$(nix_escape "$DOTFILES_NIXPKGS_URL")\";"
  DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK='inputs.nixpkgs.follows = "nixpkgs";'
fi

HOME_MANAGER_INPUT_BLOCK='home-manager.follows = "dotfiles/home-manager";'
DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK=""
if [[ -n $DOTFILES_HOME_MANAGER_URL ]]; then
  HOME_MANAGER_INPUT_BLOCK="$(
    printf '%s\n' \
      'home-manager = {' \
      "  url = \"$(nix_escape "$DOTFILES_HOME_MANAGER_URL")\";" \
      '  inputs.nixpkgs.follows = "nixpkgs";' \
      '};'
  )"
  DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK='inputs.home-manager.follows = "home-manager";'
fi

EXTRA_MODULES_BLOCK=""
if [[ $(uname -s) == Linux && ! -e /etc/NIXOS ]]; then
  EXTRA_MODULES_BLOCK="$(
    printf '%s\n' \
      'extraModules = [' \
      '  { targets.genericLinux.enable = true; }' \
      '];'
  )"
fi

mkdir -p "$HM_CONFIG_DIR"
flake_tmp=$(mktemp "$HM_CONFIG_DIR/.flake.nix.XXXXXX")
cleanup_flake_tmp() {
  [[ -z ${flake_tmp:-} ]] || rm -f "$flake_tmp"
}
trap cleanup_flake_tmp EXIT

{
  printf '%s\n' '# Generated by TheFurnace/dotfiles installer.'
  printf '%s\n' '{'
  printf '%s\n' "  description = \"Home Manager configuration for $(nix_escape "$DOTFILES_USER")\";"
  printf '\n'
  printf '%s\n' '  inputs = {'
  printf '    %s\n\n' "$NIXPKGS_INPUT_BLOCK"
  printf '%s\n\n' "$HOME_MANAGER_INPUT_BLOCK" | sed 's/^/    /'
  printf '%s\n' '    dotfiles = {'
  printf '%s\n' "      url = \"$(nix_escape "$DOTFILES_URL")\";"
  [[ -z $DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK ]] || printf '      %s\n' "$DOTFILES_INPUT_NIXPKGS_FOLLOWS_BLOCK"
  [[ -z $DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK ]] || printf '      %s\n' "$DOTFILES_INPUT_HOME_MANAGER_FOLLOWS_BLOCK"
  printf '%s\n' '    };'
  printf '%s\n' '  };'
  printf '\n'
  printf '%s\n' '  outputs = { dotfiles, ... }: {'
  printf '%s\n' "    homeConfigurations.\"$(nix_escape "$DOTFILES_USER")\" ="
  printf '%s\n' '      dotfiles.lib.mkHomeConfiguration {'
  printf '%s\n' "        system        = \"$DOTFILES_INSTALLER_SYSTEM\";"
  printf '%s\n' "        username      = \"$(nix_escape "$DOTFILES_USER")\";"
  printf '%s\n' "        homeDirectory = \"$(nix_escape "$DOTFILES_HOME")\";"
  printf '%s\n' "        stateVersion  = \"$(nix_escape "$DOTFILES_STATE_VERSION")\";"
  [[ -z $EXTRA_MODULES_BLOCK ]] || printf '%s\n' "$EXTRA_MODULES_BLOCK" | sed 's/^/        /'
  printf '%s\n' '      };'
  printf '%s\n' '  };'
  printf '%s\n' '}'
} >"$flake_tmp"

if $REPLACE_EXISTING; then
  backup_path="$FLAKE_PATH.pre-dotfiles"
  if [[ -e $backup_path || -L $backup_path ]]; then
    backup_path="$backup_path.$(date +%Y%m%d%H%M%S)"
  fi
  mv "$FLAKE_PATH" "$backup_path"
  success "Backed up the previous flake to $backup_path"
fi

mv "$flake_tmp" "$FLAKE_PATH"
flake_tmp=""
if $FLAKE_IS_MANAGED; then
  success "Refreshed $FLAKE_PATH"
else
  success "Wrote $FLAKE_PATH"
fi

say "Activating the Home Manager configuration"
home-manager switch -b backup --flake "$HM_CONFIG_DIR#$DOTFILES_USER"

if $INSTALL_AI; then
  say "Installing Pi and Codex"
  "$DOTFILES_HOME/.nix-profile/bin/dotfiles-ai" install all
fi

printf '\n%bDotfiles installed successfully.%b\n' "$green$bold" "$reset"
report_login_shell_status
