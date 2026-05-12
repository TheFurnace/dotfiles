{
  description = "Plug-and-play dotfiles for Home Manager and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "git+https://github.com/nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "git+https://github.com/nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-index-database, ... }:
    let
      defaultSystem = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${defaultSystem};

      # Keep flake.nix as composition glue only. The implementation lives in
      # ./.flake-modules so the root stays readable.
      homeModule = import ./.flake-modules/home-manager.nix {
        inherit self nix-index-database;
      };

      # The NixOS module wraps the Home Manager module and adds system-level
      # integration such as fish as a login shell.
      nixosModule = import ./.flake-modules/nixos.nix {
        inherit home-manager homeModule;
      };

      # Helper constructors mirror the exported modules so consumers can choose
      # either low-level modules or higher-level configuration builders.
      helperLib = import ./.flake-modules/lib.nix {
        inherit nixpkgs home-manager homeModule nixosModule;
      };

      validateFishConfig = pkgs.writeShellApplication {
        name = "validate-fish-config";
        runtimeInputs = [ pkgs.fish pkgs.findutils pkgs.nix ];
        text = ''
          : ''${DOTFILES_REPO:?DOTFILES_REPO is not set}

          activation_package="$(
            nix --extra-experimental-features 'nix-command flakes' \
              build --no-link --print-out-paths \
              "$DOTFILES_REPO#homeConfigurations.example.activationPackage"
          )"

          fish_config="$activation_package/home-files/.config/fish/config.fish"
          fish_functions_dir="$activation_package/home-files/.config/fish/functions"

          fish -n "$fish_config"

          if [ -d "$fish_functions_dir" ]; then
            while IFS= read -r -d '' fish_function; do
              fish -n "$fish_function"
            done < <(find "$fish_functions_dir" -type f -name '*.fish' -print0)
          fi
        '';
      };

      validateNeovimConfig = pkgs.writeShellApplication {
        name = "validate-neovim-config";
        runtimeInputs = [ pkgs.findutils pkgs.lua pkgs.neovim ];
        text = ''
          : ''${DOTFILES_REPO:?DOTFILES_REPO is not set}

          nvim_config_dir="$DOTFILES_REPO/.config/nvim"
          lua -e 'assert(loadfile(arg[1]))' "$nvim_config_dir/init.lua"

          while IFS= read -r -d '' lua_file; do
            lua -e 'assert(loadfile(arg[1]))' "$lua_file"
          done < <(find "$nvim_config_dir/lua" -type f -name '*.lua' -print0)
        '';
      };

      validateOhMyPoshConfig = pkgs.writeShellApplication {
        name = "validate-oh-my-posh-config";
        runtimeInputs = [ pkgs.oh-my-posh ];
        text = ''
          : ''${DOTFILES_REPO:?DOTFILES_REPO is not set}
          oh-my-posh config validate --config "$DOTFILES_REPO/.config/oh-my-posh/themes/lambda.omp.json"
        '';
      };

      validateKittyConfig = pkgs.writeShellApplication {
        name = "validate-kitty-config";
        runtimeInputs = [ pkgs.gnugrep pkgs.kitty pkgs.python3 ];
        text = ''
          : ''${DOTFILES_REPO:?DOTFILES_REPO is not set}

          config="$DOTFILES_REPO/.config/kitty/kitty.conf"
          output_file="$(mktemp)"
          status=0
          trap 'rm -f "$output_file"' EXIT

          kitty --config "$config" --debug-config >"$output_file" 2>&1 || status=$?

          if grep -Eiq 'Ignoring invalid config line|unknown config key|unknown option|invalid config|Traceback' "$output_file"; then
            cat "$output_file"
            exit 1
          fi

          python -m py_compile "$DOTFILES_REPO/.config/kitty/copy_or_paste.py"

          if [ "$status" -ne 0 ]; then
            cat "$output_file"
          fi
        '';
      };

      validatePwshConfig = pkgs.writeShellApplication {
        name = "validate-pwsh-config";
        runtimeInputs = [ pkgs.oh-my-posh pkgs.powershell pkgs.zoxide ];
        text = ''
          : ''${DOTFILES_REPO:?DOTFILES_REPO is not set}
          pwsh -NoLogo -NoProfile -Command ". '$DOTFILES_REPO/.config/powershell/Microsoft.PowerShell_profile.ps1'"
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

      exampleHomeConfiguration = helperLib.mkHomeConfiguration {
        username = "demo";
        homeDirectory = "/home/demo";
        stateVersion = "25.11";
      };

      exampleNixosConfiguration = helperLib.mkNixosConfiguration {
        hostname = "dotfiles-example";
        username = "demo";
        homeDirectory = "/home/demo";
        stateVersion = "25.11";
        extraModules = [
          {
            boot.isContainer = true;
          }
        ];
      };
    in
    {
      # Public helpers for downstream flakes.
      lib = helperLib;

      # Public modules for direct consumption.
      homeManagerModules.default = homeModule;
      nixosModules.default = nixosModule;

      # Small built-in examples that also exercise the exported helpers.
      homeConfigurations.example = exampleHomeConfiguration;

      nixosConfigurations.example = exampleNixosConfiguration;

      devShells.${defaultSystem}.default = pkgs.mkShell {
        packages = with pkgs; [
          fish
          just
          kitty
          neovim
          nix
          nix-your-shell
          oh-my-posh
          powershell
          tree-sitter
          zoxide
        ] ++ [
          validateDotfilesConfig
          validateFishConfig
          validateKittyConfig
          validateNeovimConfig
          validateOhMyPoshConfig
          validatePwshConfig
        ];

        shellHook = ''
          export DOTFILES_REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          export DOTFILES_DEV_HOME="${TMPDIR:-/tmp}/dotfiles-dev-shell"
          export HOME="$DOTFILES_DEV_HOME/home"
          export XDG_CONFIG_HOME="$DOTFILES_REPO/.config"
          export XDG_DATA_HOME="$HOME/.local/share"
          export XDG_STATE_HOME="$HOME/.local/state"
          export XDG_CACHE_HOME="$HOME/.cache"

          mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
          ln -snf "$DOTFILES_REPO/.config" "$HOME/.config"

          echo "dotfiles dev shell ready"
          echo "Validation commands: validate-fish-config, validate-neovim-config, validate-oh-my-posh-config, validate-kitty-config, validate-pwsh-config, validate-dotfiles-config"
        '';
      };
    };
}
