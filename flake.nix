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

      # Unlike the generic library surface above, these repository-local
      # values make a clone directly activatable. Keep personalization in one
      # obvious file instead of scattering identity through flake.nix.
      directDefaults = import ./defaults.nix;

      defaultHomeConfiguration = helperLib.mkHomeConfiguration {
        inherit (directDefaults) system username homeDirectory;
        stateVersion = directDefaults.homeStateVersion;
        extraModules = directDefaults.homeModules;
      };

      defaultNixosConfiguration = helperLib.mkNixosConfiguration {
        inherit (directDefaults) system hostname username homeDirectory;
        stateVersion = directDefaults.homeStateVersion;
        inherit (directDefaults) nixosStateVersion;
        extraModules = directDefaults.nixosModules;
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

      defaultSystem = "x86_64-linux";
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      devShellModule = import ./.flake-modules/dev-shell.nix {
        inherit nixpkgs supportedSystems;
      };

      # Evaluate the full nmt test suite for the default system.  Individual
      # test derivations are exposed as legacyPackages.test-<name> so the
      # Python runner and `nix flake check` can discover and build them.
      testSuiteFor = system: import ./tests {
        inherit self nix-index-database home-manager;
        pkgs = pkgsFor system;
      };

      installerModule = import ./.flake-modules/installer.nix {
        inherit nixpkgs home-manager self;
      };

      # NixOS VM integration tests.  Kept separate from the nmt suite above
      # because they boot real machines and exercise the user-facing
      # bootstrap flow end-to-end.
      integrationTests = import ./tests/integration {
        inherit self home-manager nixpkgs nix-index-database;
        pkgs = pkgsFor defaultSystem;
      };

      # Force the important values in both direct configurations without
      # making the fast check build an entire NixOS system closure.
      directConfigurationsCheck =
        assert defaultHomeConfiguration.config.home.username == directDefaults.username;
        assert defaultHomeConfiguration.config.home.homeDirectory == directDefaults.homeDirectory;
        assert defaultNixosConfiguration.config.networking.hostName == directDefaults.hostname;
        assert defaultNixosConfiguration.config.users.users.${directDefaults.username}.isNormalUser;
        (pkgsFor directDefaults.system).runCommand "dotfiles-direct-configurations" { } ''
          touch "$out"
        '';
    in
    {
      # Public helpers for downstream flakes.
      lib = helperLib;

      # Public modules for direct consumption.
      homeManagerModules.default = homeModule;
      nixosModules.default = nixosModule;

      # Direct clone targets plus small generic examples of the helpers.
      homeConfigurations = {
        default = defaultHomeConfiguration;
        example = exampleHomeConfiguration;
      };

      nixosConfigurations = {
        default = defaultNixosConfiguration;
        example = exampleNixosConfiguration;
      };
      devShells = devShellModule.devShells;

      # Individual nmt test derivations, prefixed with "test-" so the Python
      # runner can discover them via `nix eval .#legacyPackages.${system}`.
      legacyPackages = forAllSystems (system:
        nixpkgs.lib.mapAttrs'
          (n: nixpkgs.lib.nameValuePair "test-${n}")
          (builtins.removeAttrs (testSuiteFor system).build [ "all" ]));

      # Runnable test-runner script: `nix run .#packages.x86_64-linux.tests`
      packages = forAllSystems (system: {
        tests = (pkgsFor system).callPackage ./tests/package.nix { flake = self; };
      });

      # `nix run github:TheFurnace/dotfiles -- init [--switch]` installer.
      apps = installerModule.apps;

      # Surface the integration tests so `nix flake check` runs them and
      # `nix build .#checks.x86_64-linux.<name>` works for ad-hoc invocation.
      checks = forAllSystems (system: {
        nmt = (testSuiteFor system).build.all;
      }
      // nixpkgs.lib.optionalAttrs (system == directDefaults.system) {
        direct-configurations = directConfigurationsCheck;
      }
      // nixpkgs.lib.optionalAttrs (system == defaultSystem) integrationTests);
    };
}
