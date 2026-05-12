: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
profile="$DOTFILES_REPO/.config/powershell/Microsoft.PowerShell_profile.ps1"

test -f "$profile"
grep -q 'oh-my-posh init pwsh' "$profile"
grep -q 'zoxide init powershell' "$profile"
command -v pwsh >/dev/null
