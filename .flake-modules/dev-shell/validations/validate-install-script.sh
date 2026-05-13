: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
set -euo pipefail

install_script="$DOTFILES_REPO/install.sh"
nix_cmd=(nix --extra-experimental-features "nix-command flakes")
current_system_expr='builtins.currentSystem'
temp_root="${TMPDIR:-/tmp}"

test -x "$install_script"
bash -n "$install_script"

test_root="$(mktemp -d "$temp_root/dotfiles-install-validate.XXXXXX")"
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

test_home="$test_root/home"
mkdir -p "$test_home"

required_path_commands=(
  bash
  cat
  dirname
  grep
  id
  mktemp
  mv
  nix
  python3
  rm
  sed
)

safe_path=""
safe_path_contains_dir() {
  local dir="$1"
  case ":$safe_path:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

append_path_dir() {
  local dir="$1"
  if safe_path_contains_dir "$dir"; then
    return
  fi

  safe_path="${safe_path:+$safe_path:}$dir"
}

assert_command_absent() {
  local command_name="$1"
  local command_path

  if command_path="$(PATH="$safe_path" command -v "$command_name" 2>/dev/null)"; then
    echo "Expected $command_name to be absent from sanitized PATH, found at: $command_path" >&2
    echo "Sanitized PATH: $safe_path" >&2
    exit 1
  fi
}

for command_name in "${required_path_commands[@]}"; do
  resolved_path="$(command -v "$command_name" || true)"
  if [[ -n "$resolved_path" && "$resolved_path" == /* ]]; then
    append_path_dir "$(dirname "$resolved_path")"
  fi
done

if ! PATH="$safe_path" command -v nix >/dev/null 2>&1; then
  echo "Expected nix to be available in sanitized PATH: $safe_path" >&2
  exit 1
fi

assert_command_absent git
assert_command_absent home-manager

install_default_system="$(
  PATH="$safe_path" "${nix_cmd[@]}" eval --impure --raw --expr "$current_system_expr"
)"

export INSTALL_SCRIPT="$install_script"
install_script_bash="$(command -v bash)"
export INSTALL_SCRIPT_BASH="$install_script_bash"
export INSTALL_TEST_HOME="$test_home"
export INSTALL_TEST_PATH="$safe_path"
export INSTALL_TRANSCRIPT="$test_root/install-transcript.txt"
export INSTALL_DEFAULT_USERNAME="testuser"
export INSTALL_DEFAULT_HOME="$test_home"
export INSTALL_DEFAULT_STATE_VERSION="25.11"
export INSTALL_DEFAULT_SYSTEM="$install_default_system"

python3 "$DOTFILES_REPO/.flake-modules/dev-shell/validations/validate-install-script.py"

transcript="$INSTALL_TRANSCRIPT"

grep -Fq "Installing standalone Home Manager config from:" "$transcript"
grep -Fq "Configuration summary:" "$transcript"
grep -Fq "username:       $INSTALL_DEFAULT_USERNAME" "$transcript"
grep -Fq "home directory: $INSTALL_DEFAULT_HOME" "$transcript"
grep -Fq "state version:  $INSTALL_DEFAULT_STATE_VERSION" "$transcript"
grep -Fq "system:         $INSTALL_DEFAULT_SYSTEM" "$transcript"
grep -Fq "mutable:        false" "$transcript"
grep -Fq "Running nix flake check for: path:$DOTFILES_REPO" "$transcript"
grep -Fq "Building the generated Home Manager activation package..." "$transcript"
grep -Fq "Skipping activation." "$transcript"
