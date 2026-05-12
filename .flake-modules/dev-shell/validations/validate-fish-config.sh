fish_config="@exampleHomeConfigurationActivationPackage@/home-files/.config/fish/config.fish"
fish_functions_dir="@exampleHomeConfigurationActivationPackage@/home-files/.config/fish/functions"

fish -n "$fish_config"

if [ -d "$fish_functions_dir" ]; then
  while IFS= read -r -d $'\0' fish_function; do
    fish -n "$fish_function"
  done < <(find "$fish_functions_dir" -type f -name '*.fish' -print0)
fi
