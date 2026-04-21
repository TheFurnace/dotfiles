{
  description = "Plug-and-play dotfiles for Home Manager and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-index-database, ... }:
    let
      lib = nixpkgs.lib;
      defaultSystem = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${defaultSystem};

      mkHomeConfiguration = {
        system ? defaultSystem,
        username,
        homeDirectory,
        stateVersion,
        mutable ? false,
        localPath ? "",
        extraModules ? [ ],
      }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            self.homeManagerModules.default
            {
              dotfiles = {
                enable = true;
                inherit username homeDirectory mutable localPath;
              };

              home.stateVersion = stateVersion;
            }
          ] ++ extraModules;
        };

      mkNixosConfiguration = {
        system ? defaultSystem,
        hostname,
        username,
        homeDirectory ? "/home/${username}",
        stateVersion,
        nixosStateVersion ? stateVersion,
        mutable ? false,
        localPath ? "",
        user ? { },
        extraModules ? [ ],
      }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            ({ ... }: {
              networking.hostName = hostname;
              system.stateVersion = nixosStateVersion;

              users.users.${username} = {
                isNormalUser = true;
                home = homeDirectory;
                extraGroups = [ "wheel" ];
              } // user;

              dotfiles = {
                enable = true;
                inherit username homeDirectory stateVersion mutable localPath;
              };
            })
          ] ++ extraModules;
        };

      homeModule = { config, lib, pkgs, ... }:
        let
          cfg = config.dotfiles;

          configFilesFrom = relDir: prefix:
            let
              entries = builtins.readDir "${self}/.config/${relDir}";
              sourceFor = name:
                if cfg.mutable
                then config.lib.file.mkOutOfStoreSymlink
                  "${cfg.localPath}/.config/${prefix}${name}"
                else "${self}/.config/${relDir}/${name}";
            in
            lib.foldl' (acc: name:
              let
                type = entries.${name};
              in
              if type == "regular"
              then acc // { "${prefix}${name}".source = sourceFor name; }
              else if type == "directory"
              then acc // (configFilesFrom "${relDir}/${name}" "${prefix}${name}/")
              else acc
            ) { } (builtins.attrNames entries);
        in
        {
          imports = [ nix-index-database.homeModules.nix-index ];

          options.dotfiles = {
            enable = lib.mkEnableOption "plug-and-play dotfiles environment";

            username = lib.mkOption {
              type = lib.types.str;
              description = "The home-manager user. Sets home.username.";
            };

            homeDirectory = lib.mkOption {
              type = lib.types.str;
              description = "Absolute path to the user's home directory. Sets home.homeDirectory.";
            };

            mutable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                When false (default), config files are copied from the Nix store.
                A rebuild is required to pick up any change.

                When true, config files are live symlinks pointing into
                localPath. Edits to existing files take effect immediately
                (for example after `exec fish`); adding or removing files still
                requires a rebuild so the symlink set can be updated.
              '';
            };

            localPath = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = ''
                Absolute path to the local dotfiles checkout.
                Required, and only used, when mutable = true.
              '';
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = !cfg.mutable || cfg.localPath != "";
                message = "dotfiles.localPath must be set when dotfiles.mutable = true.";
              }
            ];

            home.username = lib.mkDefault cfg.username;
            home.homeDirectory = lib.mkDefault cfg.homeDirectory;

            # Helps downstream tools pick fish even outside NixOS.
            home.sessionVariables.SHELL = "${pkgs.fish}/bin/fish";

            fonts.fontconfig.enable = true;

            home.packages = with pkgs; [
              fish
              fira-code
              git
              kitty
              nix-your-shell
              oh-my-posh
            ];

            programs.nix-index-database.comma.enable = true;

            programs.neovim = {
              enable = true;
              defaultEditor = true;
              viAlias = true;
              vimAlias = true;
              withRuby = false;
              withPython3 = false;
            };

            programs.direnv = {
              enable = true;
              nix-direnv.enable = true;

              config.global = {
                hide_env_diff = true;
                warn_timeout = "30s";
              };
            };

            xdg.configFile =
              configFilesFrom "fish" "fish/" //
              configFilesFrom "git" "git/" //
              configFilesFrom "kitty" "kitty/" //
              configFilesFrom "nvim" "nvim/" //
              configFilesFrom "oh-my-posh" "oh-my-posh/" //
              {
                "fish/conf.d/direnv.fish".text = ''
                  ${pkgs.direnv}/bin/direnv hook fish | source
                '';

                "fish/conf.d/nix-your-shell.fish".text = ''
                  ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
                '';
              };

            home.activation.reportFishLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              current_shell="$(
                (command -v getent >/dev/null 2>&1 && getent passwd "${cfg.username}" | cut -d: -f7) || true
              )"

              if [ -n "$current_shell" ] \
                && [ "$current_shell" != "${pkgs.fish}/bin/fish" ] \
                && [ "$current_shell" != "/run/current-system/sw/bin/fish" ]; then
                echo "dotfiles: fish is installed and configured, but your login shell is still $current_shell"
                echo "dotfiles: on non-NixOS, run once: chsh -s \"$(command -v fish)\""
              fi
            '';
          };
        };

      nixosModule = { config, lib, pkgs, ... }:
        let
          cfg = config.dotfiles;
          systemUserHome = lib.attrByPath [ "users" "users" cfg.username "home" ] null config;
          effectiveHomeDirectory =
            if cfg.homeDirectory != null then cfg.homeDirectory
            else if systemUserHome != null then systemUserHome
            else "/home/${cfg.username}";
        in
        {
          imports = [ home-manager.nixosModules.home-manager ];

          options.dotfiles = {
            enable = lib.mkEnableOption "plug-and-play dotfiles environment";

            username = lib.mkOption {
              type = lib.types.str;
              description = "The NixOS user that should receive this Home Manager configuration.";
            };

            homeDirectory = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional home directory override. By default this is taken from users.users.<name>.home, or /home/<name> if unset.";
            };

            stateVersion = lib.mkOption {
              type = lib.types.str;
              description = "Home Manager state version for the managed user.";
            };

            mutable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Forwarded to the Home Manager module.";
            };

            localPath = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Forwarded to the Home Manager module when mutable = true.";
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = cfg.homeDirectory == null || systemUserHome == null || cfg.homeDirectory == systemUserHome;
                message = "dotfiles.homeDirectory must match users.users.${cfg.username}.home when both are set.";
              }
            ];

            programs.fish.enable = true;
            environment.shells = [ pkgs.fish ];

            users.users.${cfg.username} = {
              home = lib.mkDefault effectiveHomeDirectory;
              shell = pkgs.fish;
            };

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${cfg.username} = {
              imports = [ self.homeManagerModules.default ];

              dotfiles = {
                enable = true;
                username = cfg.username;
                homeDirectory = effectiveHomeDirectory;
                mutable = cfg.mutable;
                localPath = cfg.localPath;
              };

              home.stateVersion = cfg.stateVersion;
            };
          };
        };
    in
    {
      lib = {
        inherit mkHomeConfiguration mkNixosConfiguration;
      };

      homeManagerModules.default = homeModule;
      nixosModules.default = nixosModule;

      homeConfigurations.ferndq = mkHomeConfiguration {
        username = "ferndq";
        homeDirectory = "/home/ferndq";
        stateVersion = "25.11";
      };

      nixosConfigurations.example = mkNixosConfiguration {
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
    };
}
