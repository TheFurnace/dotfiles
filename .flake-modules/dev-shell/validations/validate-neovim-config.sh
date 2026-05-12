: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"

nvim_config_dir="$DOTFILES_REPO/.config/nvim"
luac -p "$nvim_config_dir/init.lua"

while IFS= read -r -d $'\0' lua_file; do
  luac -p "$lua_file"
done < <(find "$nvim_config_dir/lua" -type f -name '*.lua' -print0)
