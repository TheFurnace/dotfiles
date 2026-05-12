: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
oh-my-posh print primary --config "$DOTFILES_REPO/.config/oh-my-posh/themes/lambda.omp.json" --shell universal >/dev/null
