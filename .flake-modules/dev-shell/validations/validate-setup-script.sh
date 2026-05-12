: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
setup_script="$DOTFILES_REPO/setup.sh"
expected_link_target="$DOTFILES_REPO/.config/git/config"

test -x "$setup_script"
test -f "$expected_link_target"
bash -n "$setup_script"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup-validate.XXXXXX")"
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

export HOME="$test_root/home"
export XDG_CONFIG_HOME="$test_root/config"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

"$setup_script" >/dev/null

test -L "$XDG_CONFIG_HOME/git/config"
[ "$(readlink "$XDG_CONFIG_HOME/git/config")" = "$expected_link_target" ]
