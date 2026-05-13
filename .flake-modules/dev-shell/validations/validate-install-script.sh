: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
install_script="$DOTFILES_REPO/install.sh"

test -x "$install_script"
bash -n "$install_script"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-validate.XXXXXX")"
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

nix_bin="$(command -v nix)"
script_bin="$(command -v script || true)"
if [ -z "$script_bin" ] && [ -x /usr/bin/script ]; then
  script_bin=/usr/bin/script
fi
if [ -z "$script_bin" ]; then
  echo "Error: script utility not found. Required for install validation." >&2
  exit 1
fi
if ! nixpkgs_path="$(
  cd "$DOTFILES_REPO"
  "$nix_bin" --extra-experimental-features "nix-command flakes" eval --impure --raw --expr 'let flake = builtins.getFlake (toString ./.); in flake.inputs.nixpkgs.outPath'
)"; then
  echo "Error: failed to resolve the flake-pinned nixpkgs path for install validation." >&2
  exit 1
fi
nix_only_bin_dir="$test_root/nix-only-bin"
mkdir -p "$nix_only_bin_dir"
ln -s "$nix_bin" "$nix_only_bin_dir/nix"

answers_file="$test_root/install-input.txt"
# Feed more empty responses than the installer currently consumes so it can keep
# accepting defaults if a prompt or two is added later.
{
  for _ in $(seq 1 16); do
    printf '\n'
  done
} >"$answers_file"

install_command=(
  "$nix_bin"
  --extra-experimental-features
  "nix-command flakes"
  shell
  "$nixpkgs_path#bash"
  "$nixpkgs_path#coreutils"
  "$nixpkgs_path#gnused"
  -c
  bash
  "$install_script"
)
printf -v install_command_string '%q ' "${install_command[@]}"

env -i \
  HOME="$test_root/home" \
  PATH="$nix_only_bin_dir" \
  TERM="${TERM:-xterm}" \
  TMPDIR="$test_root" \
  USER="${USER:-$(id -un)}" \
  "$script_bin" -qec "$install_command_string" /dev/null <"$answers_file"
