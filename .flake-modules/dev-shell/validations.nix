{ pkgs, exampleHomeConfiguration }:
let
  validateFishConfig = pkgs.writeShellApplication {
    name = "validate-fish-config";
    runtimeInputs = [ pkgs.fish pkgs.findutils ];
    text = ''
      fish_config="${exampleHomeConfiguration.activationPackage}/home-files/.config/fish/config.fish"
      fish_functions_dir="${exampleHomeConfiguration.activationPackage}/home-files/.config/fish/functions"

      fish -n "$fish_config"

      if [ -d "$fish_functions_dir" ]; then
        while IFS= read -r -d $'\0' fish_function; do
          fish -n "$fish_function"
        done < <(find "$fish_functions_dir" -type f -name '*.fish' -print0)
      fi
    '';
  };

  validateNeovimConfig = pkgs.writeShellApplication {
    name = "validate-neovim-config";
    runtimeInputs = [ pkgs.findutils pkgs.lua pkgs.neovim ];
    text = ''
      : "''${DOTFILES_REPO:?DOTFILES_REPO is not set}"

      nvim_config_dir="$DOTFILES_REPO/.config/nvim"
      luac -p "$nvim_config_dir/init.lua"

      while IFS= read -r -d $'\0' lua_file; do
        luac -p "$lua_file"
      done < <(find "$nvim_config_dir/lua" -type f -name '*.lua' -print0)
    '';
  };

  validateOhMyPoshConfig = pkgs.writeShellApplication {
    name = "validate-oh-my-posh-config";
    runtimeInputs = [ pkgs.oh-my-posh ];
    text = ''
      : "''${DOTFILES_REPO:?DOTFILES_REPO is not set}"
      oh-my-posh print primary --config "$DOTFILES_REPO/.config/oh-my-posh/themes/lambda.omp.json" --shell universal >/dev/null
    '';
  };

  validateKittyConfig = pkgs.writeShellApplication {
    name = "validate-kitty-config";
    runtimeInputs = [ pkgs.kitty pkgs.python3 ];
    text = ''
      : "''${DOTFILES_REPO:?DOTFILES_REPO is not set}"
      kitty_bin="$(readlink -f "$(command -v kitty)")"
      kitty_lib="$(dirname "$kitty_bin")/../lib/kitty"

      python -m py_compile "$DOTFILES_REPO/.config/kitty/copy_or_paste.py"
      PYTHONPATH="$kitty_lib''${PYTHONPATH:+:$PYTHONPATH}" python - <<'PY'
      import os
      import sys
      import kitty.config

      bad_lines = []
      kitty.config.load_config(
          os.path.join(os.environ["DOTFILES_REPO"], ".config/kitty/kitty.conf"),
          accumulate_bad_lines=bad_lines,
      )

      if bad_lines:
          for bad_line in bad_lines:
              print(bad_line, file=sys.stderr)
          raise SystemExit(1)
      PY
    '';
  };

  validatePwshConfig = pkgs.writeShellApplication {
    name = "validate-pwsh-config";
    runtimeInputs = [ pkgs.gnugrep pkgs.powershell ];
    text = ''
      : "''${DOTFILES_REPO:?DOTFILES_REPO is not set}"
      profile="$DOTFILES_REPO/.config/powershell/Microsoft.PowerShell_profile.ps1"

      test -f "$profile"
      grep -q 'oh-my-posh init pwsh' "$profile"
      grep -q 'zoxide init powershell' "$profile"
      command -v pwsh >/dev/null
    '';
  };

  validateDotfilesConfig = pkgs.writeShellApplication {
    name = "validate-dotfiles-config";
    runtimeInputs = [
      validateFishConfig
      validateNeovimConfig
      validateOhMyPoshConfig
      validateKittyConfig
      validatePwshConfig
    ];
    text = ''
      validate-fish-config
      validate-neovim-config
      validate-oh-my-posh-config
      validate-kitty-config
      validate-pwsh-config
    '';
  };
in
{
  validationPackages = [
    validateDotfilesConfig
    validateFishConfig
    validateKittyConfig
    validateNeovimConfig
    validateOhMyPoshConfig
    validatePwshConfig
  ];
}
