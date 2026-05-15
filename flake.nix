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

      devShellModule = import ./.flake-modules/dev-shell.nix {
        inherit nixpkgs exampleHomeConfiguration;
      };

      defaultSystem = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${defaultSystem};

      # Evaluate the full nmt test suite for the default system.  Individual
      # test derivations are exposed as legacyPackages.test-<name> so the
      # Python runner and `nix flake check` can discover and build them.
      testSuite = import ./tests {
        inherit self nix-index-database home-manager pkgs;
      };

      installerModule = import ./.flake-modules/installer.nix {
        inherit nixpkgs home-manager self;
      };

      # NixOS VM integration tests.  Kept separate from the nmt suite above
      # because they boot real machines and exercise the user-facing
      # bootstrap flow end-to-end.
      integrationTests = import ./tests/integration {
        inherit pkgs self home-manager nixpkgs;
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
      devShells = devShellModule.devShells;

      # Individual nmt test derivations, prefixed with "test-" so the Python
      # runner can discover them via `nix eval .#legacyPackages.${system}`.
      legacyPackages.${defaultSystem} =
        nixpkgs.lib.mapAttrs'
          (n: nixpkgs.lib.nameValuePair "test-${n}")
          testSuite.build;

      # Runnable test-runner script: `nix run .#packages.x86_64-linux.tests`
      packages.${defaultSystem}.tests =
        pkgs.callPackage ./tests/package.nix { flake = self; };

      # `nix run github:TheFurnace/dotfiles -- init [--switch]` installer.
      apps = installerModule.apps;

      # Surface the integration tests so `nix flake check` runs them and
      # `nix build .#checks.x86_64-linux.<name>` works for ad-hoc invocation.
      checks.${defaultSystem} = integrationTests;
    };
}
