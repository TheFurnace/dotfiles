#!/usr/bin/env -S nix --extra-experimental-features nix-command --extra-experimental-features flakes shell nixpkgs#bash nixpkgs#git nixpkgs#home-manager --command bash

set -euo pipefail

bootstrap_cmd=(
    nix
    --extra-experimental-features
    nix-command
    --extra-experimental-features
    flakes
    shell
    nixpkgs#bash
    nixpkgs#git
    nixpkgs#home-manager
    --command
    bash
)

temp_script="$(mktemp "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
cleanup() {
    rm -f "$temp_script"
}
trap cleanup EXIT

source_script_path="${BASH_SOURCE[0]-}"
source_script_dir=""
nix_path="$(command -v nix)"
if command -v readlink >/dev/null 2>&1; then
    resolved_nix_path="$(readlink -f "$nix_path" 2>/dev/null || true)"
    if [ -n "$resolved_nix_path" ]; then
        nix_path="$resolved_nix_path"
    fi
fi
nix_bin_dir="$(cd "$(dirname "$nix_path")" && pwd)"
if [ -n "$source_script_path" ] && [ -e "$source_script_path" ]; then
    candidate_source_dir="$(cd "$(dirname "$source_script_path")" && pwd)"
    if [ -f "$candidate_source_dir/flake.nix" ] && [ -f "$candidate_source_dir/install.sh" ]; then
        source_script_dir="$candidate_source_dir"
    fi
fi

bootstrap_inputs_from=""
if [ -n "$source_script_dir" ]; then
    bootstrap_inputs_from="path:$source_script_dir"
elif [[ "${DOTFILES_INSTALL_DOTFILES_URL:-}" == path:* ]] && [ -d "${DOTFILES_INSTALL_DOTFILES_URL#path:}" ] && [ -f "${DOTFILES_INSTALL_DOTFILES_URL#path:}/flake.nix" ]; then
    bootstrap_inputs_from="$DOTFILES_INSTALL_DOTFILES_URL"
fi

if [ -n "$bootstrap_inputs_from" ]; then
    bootstrap_cmd=(
        nix
        --extra-experimental-features
        nix-command
        --extra-experimental-features
        flakes
        shell
        --inputs-from
        "$bootstrap_inputs_from"
        nixpkgs#bash
        nixpkgs#git
        nixpkgs#home-manager
        --command
        bash
    )
fi

cat >"$temp_script" <<'SCRIPT'
#!/usr/bin/env bash

set -euo pipefail

nix_cmd=(nix --extra-experimental-features "nix-command flakes")
default_state_version="25.11"
default_dotfiles_url="github:TheFurnace/dotfiles"
xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
home_manager_dir="$xdg_config_home/home-manager"
flake_path="$home_manager_dir/flake.nix"

nix_config_line='experimental-features = nix-command flakes'
if [ -n "${NIX_CONFIG:-}" ]; then
    printf -v NIX_CONFIG '%s\n%s' "$NIX_CONFIG" "$nix_config_line"
else
    NIX_CONFIG="$nix_config_line"
fi
export NIX_CONFIG

if [ -n "${DOTFILES_INSTALL_NIX_BIN_DIR:-}" ]; then
    case ":$PATH:" in
        *":${DOTFILES_INSTALL_NIX_BIN_DIR}:"*) ;;
        *) PATH="${DOTFILES_INSTALL_NIX_BIN_DIR}:$PATH" ;;
    esac
    export PATH
fi

resolve_dotfiles_url() {
    if [ -n "${DOTFILES_INSTALL_SOURCE_DIR:-}" ] && [ -f "${DOTFILES_INSTALL_SOURCE_DIR}/flake.nix" ] && [ -f "${DOTFILES_INSTALL_SOURCE_DIR}/install.sh" ]; then
        printf 'path:%s\n' "$DOTFILES_INSTALL_SOURCE_DIR"
        return
    fi

    printf '%s\n' "$default_dotfiles_url"
}

nix_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$\{/\\\$\{}"
    printf '%s' "$value"
}

default_username="${USER:-$(id -un)}"
default_home_directory="${HOME:-/home/$default_username}"
default_system="$("${nix_cmd[@]}" eval --impure --raw --expr 'builtins.currentSystem')"
dotfiles_url="${DOTFILES_INSTALL_DOTFILES_URL:-$(resolve_dotfiles_url)}"
configuration_name="${DOTFILES_INSTALL_FLAKE_ATTR:-$default_username}"
username="${DOTFILES_INSTALL_USERNAME:-$default_username}"
home_directory="${DOTFILES_INSTALL_HOME_DIRECTORY:-$default_home_directory}"
state_version="${DOTFILES_INSTALL_STATE_VERSION:-$default_state_version}"
system="${DOTFILES_INSTALL_SYSTEM:-$default_system}"
mutable="${DOTFILES_INSTALL_MUTABLE:-false}"
local_path="${DOTFILES_INSTALL_LOCAL_PATH:-}"

case "$mutable" in
    true|false) ;;
    *)
        echo "DOTFILES_INSTALL_MUTABLE must be true or false, got: $mutable" >&2
        exit 1
        ;;
esac

if [ "$mutable" = "true" ] && [ -z "$local_path" ] && [[ "$dotfiles_url" == path:* ]]; then
    local_path="${dotfiles_url#path:}"
fi

if [ "$mutable" = "true" ] && [ -z "$local_path" ]; then
    echo "DOTFILES_INSTALL_LOCAL_PATH is required when DOTFILES_INSTALL_MUTABLE=true." >&2
    exit 1
fi

if [ "$mutable" = "true" ] && { [ ! -d "$local_path" ] || [ ! -f "$local_path/flake.nix" ] || [ ! -f "$local_path/install.sh" ]; }; then
    echo "DOTFILES_INSTALL_LOCAL_PATH must point at a dotfiles checkout: $local_path" >&2
    exit 1
fi

mkdir -p "$home_manager_dir"

if [ ! -f "$flake_path" ]; then
    echo "Creating initial Home Manager flake at: $flake_path"
    cat >"$flake_path" <<EOF
{
  description = "Home Manager config for TheFurnace/dotfiles";

  inputs.dotfiles.url = "$(nix_escape "$dotfiles_url")";

  outputs = { dotfiles, ... }: {
    homeConfigurations."$(nix_escape "$configuration_name")" = dotfiles.lib.mkHomeConfiguration {
      system = "$(nix_escape "$system")";
      username = "$(nix_escape "$username")";
      homeDirectory = "$(nix_escape "$home_directory")";
      stateVersion = "$(nix_escape "$state_version")";
      mutable = $mutable;
      localPath = "$(nix_escape "$local_path")";
    };
  };
}
EOF
else
    echo "Using existing Home Manager flake at: $flake_path"
fi

echo "Building Home Manager configuration: $configuration_name"
home-manager build --flake "$home_manager_dir#$configuration_name"

echo "Activating Home Manager configuration: $configuration_name"
home-manager switch -b backup --flake "$home_manager_dir#$configuration_name"
SCRIPT

chmod +x "$temp_script"

if command -v git >/dev/null 2>&1 && command -v home-manager >/dev/null 2>&1; then
    exec env DOTFILES_INSTALL_NIX_BIN_DIR="$nix_bin_dir" DOTFILES_INSTALL_SOURCE_DIR="$source_script_dir" bash "$temp_script" "$@"
fi

exec "${bootstrap_cmd[@]}" -c 'exec env DOTFILES_INSTALL_NIX_BIN_DIR="$1" DOTFILES_INSTALL_SOURCE_DIR="$2" bash "$3" "${@:4}"' bash "$nix_bin_dir" "$source_script_dir" "$temp_script" "$@"
