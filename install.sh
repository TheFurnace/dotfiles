#!/usr/bin/env bash

set -euo pipefail

nix_cmd=(nix --extra-experimental-features "nix-command flakes")
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

    read -r -p "$label [$default_value]: " value
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
        read -r -p "$label [$prompt]: " reply
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

default_username="${USER:-$(id -un)}"
default_home="${HOME:-/home/$default_username}"
default_system="$("${nix_cmd[@]}" eval --impure --raw --expr 'builtins.currentSystem')"
default_state_version="25.11"

echo "Installing standalone Home Manager config from:"
echo "  $repo_root"
echo

username="$(prompt_with_default "Username" "$default_username")"
home_directory="$(prompt_with_default "Home directory" "$default_home")"
state_version="$(prompt_with_default "Home Manager state version" "$default_state_version")"
system="$(prompt_with_default "System" "$default_system")"
mutable="$(prompt_yes_no "Enable mutable mode" "false")"
local_path=""
mutable_literal="false"

if [ "$mutable" = "true" ]; then
    mutable_literal="true"
fi

if [ "$mutable" = "true" ]; then
    local_path="$(prompt_with_default "Mutable checkout path" "$repo_root")"
fi

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
cleanup() {
    rm -rf "$temp_dir"
}
trap cleanup EXIT

cat >"$temp_dir/flake.nix" <<EOF
{
  description = "Temporary installer for TheFurnace/dotfiles";

  inputs = {
    dotfiles.url = "path:$(nix_escape "$repo_root")";
    nixpkgs.follows = "dotfiles/nixpkgs";
    home-manager.follows = "dotfiles/home-manager";
  };

  outputs = { dotfiles, home-manager, nixpkgs, ... }:
    let
      system = "$(nix_escape "$system")";
      homeManagerPackage =
        if home-manager ? packages && builtins.hasAttr system home-manager.packages
        then home-manager.packages.\${system}.default
        else home-manager.defaultPackage.\${system};
    in
    {
      homeConfigurations.installer = dotfiles.lib.mkHomeConfiguration {
        inherit system;
        username = "$(nix_escape "$username")";
        homeDirectory = "$(nix_escape "$home_directory")";
        stateVersion = "$(nix_escape "$state_version")";
        mutable = $mutable_literal;
        localPath = "$(nix_escape "$local_path")";
      };

      packages.\${system} = {
        git-cli = nixpkgs.legacyPackages.\${system}.git;
        home-manager-cli = homeManagerPackage;
      };
    };
}
EOF

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

echo "Running nix flake check for this repository..."
"${nix_cmd[@]}" flake check "$repo_root"

echo "Building the generated Home Manager activation package..."
"${nix_cmd[@]}" build --no-link "$temp_dir#homeConfigurations.installer.activationPackage"

if [ "$(prompt_yes_no "Activate this Home Manager configuration now" "false")" != "true" ]; then
    echo "Skipping activation."
    exit 0
fi

"${nix_cmd[@]}" shell \
    "$temp_dir#git-cli" \
    "$temp_dir#home-manager-cli" \
    -c home-manager switch --flake "$temp_dir#installer"
