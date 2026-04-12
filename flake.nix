{
  description = "Personal dotfiles";

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

  outputs = { self, nixpkgs, home-manager, nix-index-database }:
    let
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
    in {

      # ── Standalone home environment ──────────────────────────────────────
      # Apply with:
      #   home-manager switch --flake .#ferndq
      homeConfigurations.ferndq = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          self.homeManagerModules.default
          {
            home.username      = "ferndq";
            home.homeDirectory = "/home/ferndq";
            home.stateVersion  = "25.11";
          }
        ];
      };

      # ── Reusable module ──────────────────────────────────────────────────
      # Consumed by NixOS (or any other system) via:
      #   dotfiles.homeManagerModules.default
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.dotfiles;

          # Recursively walk self's .config/<relDir>, building xdg.configFile
          # entries. In mutable mode the source is a live symlink into
          # cfg.localPath; in immutable mode it is a plain store path.
          configFilesFrom = relDir: prefix:
            let
              entries = builtins.readDir "${self}/.config/${relDir}";
              sourceFor = name:
                if cfg.mutable
                then config.lib.file.mkOutOfStoreSymlink
                       "${cfg.localPath}/.config/${prefix}${name}"
                else "${self}/.config/${relDir}/${name}";
            in lib.foldl' (acc: name:
              let type = entries.${name};
              in if type == "regular"
                 then acc // { "${prefix}${name}".source = sourceFor name; }
                 else if type == "directory"
                 then acc // (configFilesFrom "${relDir}/${name}" "${prefix}${name}/")
                 else acc
            ) { } (builtins.attrNames entries);

        in
        {
          imports = [ nix-index-database.hmModules.nix-index ];

          options.dotfiles = {

            mutable = lib.mkOption {
              type    = lib.types.bool;
              default = false;
              description = ''
                When false (default), config files are Nix store copies.
                A rebuild is required to pick up any change.

                When true, config files are live symlinks pointing into
                localPath. Edits to existing files take effect immediately
                (e.g. after `exec fish`); adding or removing files still
                requires a rebuild so the symlink set can be updated.
              '';
            };

            localPath = lib.mkOption {
              type    = lib.types.str;
              default = "";
              description = ''
                Absolute path to the local dotfiles checkout.
                Required (and only used) when mutable = true.
              '';
            };

          };

          config = {

            # ── Packages ───────────────────────────────────────────────────
            home.packages = with pkgs; [
              kitty
              nix-your-shell
              oh-my-posh
            ];

            # ── nix-index-database + comma ─────────────────────────────────
            # Uses a pre-built database fetched from nix-index-database rather
            # than running nix-index locally (which gets OOM-killed on most
            # machines). The comma integration wires "," to use the database.
            programs.nix-index-database.comma.enable = true;

            # ── Neovim ─────────────────────────────────────────────────────
            # Config files live in .config/nvim/ (managed below).
            programs.neovim = {
              enable        = true;
              defaultEditor = true;
              viAlias       = true;
              vimAlias      = true;
              withRuby      = false;
              withPython3   = false;
            };

            # ── direnv + nix-direnv ────────────────────────────────────────
            # programs.fish is NOT enabled here (the dotfiles module owns
            # fish/config.fish via xdg.configFile — enabling programs.fish
            # would conflict). The hook is wired manually via conf.d/ which
            # fish sources automatically on every interactive session.
            programs.direnv = {
              enable            = true;
              nix-direnv.enable = true;

              config.global = {
                hide_env_diff = true;
                warn_timeout  = "30s";
              };
            };

            # ── Config files ───────────────────────────────────────────────
            xdg.configFile =
              configFilesFrom "git"        "git/"        //
              configFilesFrom "fish"       "fish/"       //
              configFilesFrom "kitty"      "kitty/"      //
              configFilesFrom "oh-my-posh" "oh-my-posh/" //
              configFilesFrom "nvim"       "nvim/"       //
              {
                # direnv hook — conf.d/ is auto-sourced by fish
                "fish/conf.d/direnv.fish".text = ''
                  ${pkgs.direnv}/bin/direnv hook fish | source
                '';
              };

          };
        };
    };
}
