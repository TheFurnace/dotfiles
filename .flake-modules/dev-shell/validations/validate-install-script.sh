: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
install_script="$DOTFILES_REPO/install.sh"

test -x "$install_script"
bash -n "$install_script"

grep -q 'flake check' "$install_script"
grep -Fq "build --no-link \"\$temp_dir#homeConfigurations.installer.activationPackage\"" "$install_script"
grep -q 'Activate this Home Manager configuration now' "$install_script"
