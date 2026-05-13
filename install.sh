#!/usr/bin/env bash

set -euo pipefail

nix_cmd=(nix --extra-experimental-features "nix-command flakes")
default_mutable_checkout_subdir="dotfiles"

resolve_dotfiles_url() {
    local script_path script_dir

    script_path="${BASH_SOURCE[0]-}"
    if [ -n "$script_path" ] && [ "$script_path" != "bash" ] && [ -e "$script_path" ]; then
        script_dir="$(cd "$(dirname "$script_path")" && pwd)"
        if [ -f "$script_dir/flake.nix" ]; then
            printf 'path:%s\n' "$script_dir"
            return
        fi
    fi

    printf 'github:TheFurnace/dotfiles\n'
}

nix_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$\{/\\\$\{}"
    printf '%s' "$value"
}

prompt_with_default() {
    local label="$1"
    local default_value="$2"
    local value

    read -r -p "$label [$default_value]: " value </dev/tty
    if [ -z "$value" ]; then
        value="$default_value"
    fi

    printf '%s' "$value"
}

prompt_yes_no() {
    local label="$1"
    local default_value="$2"
    local prompt
    local reply

    if [ "$default_value" = "true" ]; then
        prompt="Y/n"
    else
        prompt="y/N"
    fi

    while true; do
        read -r -p "$label [$prompt]: " reply </dev/tty
        if [ -z "$reply" ]; then
            printf '%s\n' "$default_value"
            return
        fi

        case "${reply,,}" in
            y|yes)
                printf 'true\n'
                return
                ;;
            n|no)
                printf 'false\n'
                return
                ;;
        esac

        echo "Please answer yes or no."
    done
}

escape_sed_replacement() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//&/\\&}
    value=${value//|/\\|}
    printf '%s' "$value"
}

escape_for_nix_sed() {
    escape_sed_replacement "$(nix_escape "$1")"
}

validate_local_checkout_path() {
    local checkout_path="$1"

    if [ ! -d "$checkout_path" ]; then
        echo "Mutable checkout path does not exist: $checkout_path" >&2
        exit 1
    fi

    if [ ! -f "$checkout_path/flake.nix" ] || [ ! -f "$checkout_path/install.sh" ]; then
        echo "Mutable checkout path must contain flake.nix and install.sh from this dotfiles repo: $checkout_path" >&2
        exit 1
    fi
}

default_username="${USER:-$(id -un)}"
default_home="${HOME:-/home/$default_username}"
default_state_version="25.11"
dotfiles_url="$(resolve_dotfiles_url)"

echo "Installing standalone Home Manager config from:"
echo "  $dotfiles_url"
echo

username="${DOTFILES_INSTALL_USERNAME:-$(prompt_with_default "Username" "$default_username")}"
home_directory="${DOTFILES_INSTALL_HOME:-$(prompt_with_default "Home directory" "$default_home")}"
state_version="${DOTFILES_INSTALL_STATE_VERSION:-$(prompt_with_default "Home Manager state version" "$default_state_version")}"
if [ -n "${DOTFILES_INSTALL_SYSTEM+x}" ]; then
    system="$DOTFILES_INSTALL_SYSTEM"
else
    default_system="$("${nix_cmd[@]}" eval --impure --raw --expr 'builtins.currentSystem')"
    system="$(prompt_with_default "System" "$default_system")"
fi
mutable="${DOTFILES_INSTALL_MUTABLE:-$(prompt_yes_no "Enable mutable mode" "false")}"
local_path=""

case "$mutable" in
    true|false)
        mutable_literal="$mutable"
        ;;
    *)
        echo "Invalid mutable mode value: $mutable" >&2
        exit 1
        ;;
esac

if [ "$mutable" = "true" ]; then
    if [[ "$dotfiles_url" == path:* ]]; then
        local_checkout_path="${dotfiles_url#path:}"
    else
        local_checkout_path="$default_home/$default_mutable_checkout_subdir"
    fi
    local_path="$(prompt_with_default "Mutable checkout path" "$local_checkout_path")"
    validate_local_checkout_path "$local_path"
fi

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
cleanup() {
    rm -rf "$temp_dir"
}
trap cleanup EXIT

cat >"$temp_dir/flake.nix" <<'EOF'
{
  description = "Temporary installer for TheFurnace/dotfiles";

  inputs = {
    dotfiles.url = "__DOTFILES_URL__";
    nixpkgs.follows = "dotfiles/nixpkgs";
    home-manager.follows = "dotfiles/home-manager";
  };

  outputs = { dotfiles, home-manager, nixpkgs, ... }:
    let
      system = "__SYSTEM__";
      homeManagerPackage =
        if home-manager ? packages && builtins.hasAttr system home-manager.packages
        then home-manager.packages.${system}.default
        else home-manager.defaultPackage.${system};
    in
    {
      homeConfigurations.installer = dotfiles.lib.mkHomeConfiguration {
        inherit system;
        username = "__USERNAME__";
        homeDirectory = "__HOME_DIRECTORY__";
        stateVersion = "__STATE_VERSION__";
        mutable = __MUTABLE__;
        localPath = "__LOCAL_PATH__";
      };

      packages.${system} = {
        git-cli = nixpkgs.legacyPackages.${system}.git;
        home-manager-cli = homeManagerPackage;
      };
    };
}
EOF

dotfiles_url_escaped="$(escape_for_nix_sed "$dotfiles_url")"
system_escaped="$(escape_for_nix_sed "$system")"
username_escaped="$(escape_for_nix_sed "$username")"
home_directory_escaped="$(escape_for_nix_sed "$home_directory")"
state_version_escaped="$(escape_for_nix_sed "$state_version")"
mutable_literal_escaped="$(escape_sed_replacement "$mutable_literal")"
local_path_escaped="$(escape_for_nix_sed "$local_path")"

sed \
    -e "s|__DOTFILES_URL__|$dotfiles_url_escaped|g" \
    -e "s|__SYSTEM__|$system_escaped|g" \
    -e "s|__USERNAME__|$username_escaped|g" \
    -e "s|__HOME_DIRECTORY__|$home_directory_escaped|g" \
    -e "s|__STATE_VERSION__|$state_version_escaped|g" \
    -e "s|__MUTABLE__|$mutable_literal_escaped|g" \
    -e "s|__LOCAL_PATH__|$local_path_escaped|g" \
    "$temp_dir/flake.nix" >"$temp_dir/flake.nix.tmp"

mv "$temp_dir/flake.nix.tmp" "$temp_dir/flake.nix"

echo
echo "Configuration summary:"
echo "  username:       $username"
echo "  home directory: $home_directory"
echo "  state version:  $state_version"
echo "  system:         $system"
echo "  mutable:        $mutable"
if [ "$mutable" = "true" ]; then
    echo "  local path:     $local_path"
fi
echo

if [ "${DOTFILES_INSTALL_SKIP_NIX_OPS:-false}" = "true" ]; then
    echo "Skipping nix flake check, build, and activation (DOTFILES_INSTALL_SKIP_NIX_OPS=true)."
    exit 0
fi

echo "Running nix flake check for: $dotfiles_url"
"${nix_cmd[@]}" flake check "$dotfiles_url"

echo "Building the generated Home Manager activation package..."
"${nix_cmd[@]}" build --no-link "$temp_dir#homeConfigurations.installer.activationPackage"

activate="${DOTFILES_INSTALL_ACTIVATE:-$(prompt_yes_no "Activate this Home Manager configuration now" "false")}"
if [ "$activate" != "true" ]; then
    echo "Skipping activation."
    exit 0
fi

"${nix_cmd[@]}" shell \
    "$temp_dir#git-cli" \
    "$temp_dir#home-manager-cli" \
    -c home-manager switch --flake "$temp_dir#installer"
