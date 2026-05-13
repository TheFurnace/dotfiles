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
nixpkgs_path="$(
  cd "$DOTFILES_REPO"
  "$nix_bin" --extra-experimental-features "nix-command flakes" eval --impure --raw --expr 'let flake = builtins.getFlake (toString ./.); in flake.inputs.nixpkgs.outPath'
)"
nix_path="$(dirname "$nix_bin")"

answers_file="$test_root/install-input.txt"
# Feed six empty responses: one for each of the installer's five configuration prompts,
# plus one to keep the default no for activation.
cat >"$answers_file" <<'EOF'






EOF

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
  PATH="$nix_path" \
  TERM="${TERM:-xterm}" \
  TMPDIR="$test_root" \
  USER="${USER:-$(id -un)}" \
  "$script_bin" -qec "$install_command_string" /dev/null <"$answers_file"
