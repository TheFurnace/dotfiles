: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
set -euo pipefail

install_script="$DOTFILES_REPO/install.sh"
temp_root="${TMPDIR:-/tmp}"
test_root="$(mktemp -d "$temp_root/dotfiles-install-validate.XXXXXX")"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

test_home="$test_root/home"
test_xdg_config_home="$test_home/.config"
test_transcript_first="$test_root/install-first.txt"
test_transcript_second="$test_root/install-second.txt"
test_flake_snapshot="$test_root/flake.nix.snapshot"
mkdir -p "$test_xdg_config_home" "$test_root/tmp"

test -x "$install_script"
bash -n "$install_script"

required_path_commands=(
  bash
  cat
  dirname
  id
  mkdir
  mktemp
  nix
  pwd
  rm
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

run_install_via_pipe() {
  local transcript="$1"

  cat "$install_script" | env -i \
    DOTFILES_INSTALL_DOTFILES_URL="path:$DOTFILES_REPO" \
    HOME="$test_home" \
    PATH="$safe_path" \
    TMPDIR="$test_root/tmp" \
    USER="testuser" \
    XDG_CONFIG_HOME="$test_xdg_config_home" \
    bash >"$transcript" 2>&1
}

run_install_via_pipe "$test_transcript_first"

flake_path="$test_xdg_config_home/home-manager/flake.nix"
test -f "$flake_path"
cp "$flake_path" "$test_flake_snapshot"

grep -Fq "Creating initial Home Manager flake at: $flake_path" "$test_transcript_first"
grep -Fq "Building Home Manager configuration: testuser" "$test_transcript_first"
grep -Fq "Activating Home Manager configuration: testuser" "$test_transcript_first"
grep -Fq "inputs.dotfiles.url = \"path:$DOTFILES_REPO\";" "$flake_path"
grep -Fq "homeConfigurations.\"testuser\"" "$flake_path"

run_install_via_pipe "$test_transcript_second"

cmp -s "$flake_path" "$test_flake_snapshot"
grep -Fq "Using existing Home Manager flake at: $flake_path" "$test_transcript_second"
grep -Fq "Building Home Manager configuration: testuser" "$test_transcript_second"
grep -Fq "Activating Home Manager configuration: testuser" "$test_transcript_second"
