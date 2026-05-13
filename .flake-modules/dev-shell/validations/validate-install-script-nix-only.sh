: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
install_script="$DOTFILES_REPO/install.sh"

# Build a PATH that contains nix but not git, simulating a fresh Linux install
# where only nix is available on the host.
# Strategy: walk PATH and drop any directory that provides a git binary.
safe_path=""
while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    if [ -x "$dir/git" ]; then
        continue  # drop directories that contain git
    fi
    safe_path="${safe_path:+$safe_path:}$dir"
done < <(printf '%s' "$PATH" | tr ':' '\n')

# Sanity-check: nix must still be reachable after the filter.
if ! PATH="$safe_path" command -v nix >/dev/null 2>&1; then
    echo "FAIL: nix is not available in the sanitized PATH; cannot run nix-only validation" >&2
    exit 1
fi

# Sanity-check: git must NOT be reachable after the filter.
if PATH="$safe_path" command -v git >/dev/null 2>&1; then
    echo "FAIL: git is still reachable in the sanitized PATH; the nix-only test cannot proceed" >&2
    exit 1
fi

# Create an isolated temp home for the test run.
test_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-nix-only-validate.XXXXXX")"
cleanup() {
    rm -rf "$test_home"
}
trap cleanup EXIT

# Run install.sh under the sanitized environment:
#   PATH  — nix present, git absent
#   DOTFILES_INSTALL_* — all prompts pre-filled so /dev/tty is never touched
#   DOTFILES_INSTALL_SKIP_NIX_OPS=true — skip the expensive nix flake check /
#     nix build steps so the test stays fast and hermetic; we are validating
#     that the script initialises and generates its config without host git,
#     not re-running the full build that nix flake check already covers.
PATH="$safe_path" \
    HOME="$test_home" \
    DOTFILES_INSTALL_USERNAME="testuser" \
    DOTFILES_INSTALL_HOME="$test_home" \
    DOTFILES_INSTALL_STATE_VERSION="25.11" \
    DOTFILES_INSTALL_SYSTEM="x86_64-linux" \
    DOTFILES_INSTALL_MUTABLE="false" \
    DOTFILES_INSTALL_ACTIVATE="false" \
    DOTFILES_INSTALL_SKIP_NIX_OPS="true" \
    "$install_script"

echo "install.sh completed successfully in a nix-only environment (no host git)."
