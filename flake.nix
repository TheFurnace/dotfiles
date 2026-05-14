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
      lib = nixpkgs.lib;

      # Scenario-based Nix checks (one derivation per behaviour).
      scenarioChecks = import ./tests {
        inherit pkgs lib self nixpkgs home-manager homeModule helperLib exampleHomeConfiguration;
      };

      # Wrap the sandboxable shell validators as a single check derivation.
      # validate-install-script is excluded because it requires impure Nix
      # evaluation and a PTY; it remains available in the dev shell only.
      configLintsCheck = pkgs.runCommand "config-lints" {
        nativeBuildInputs = [
          devShellModule.validationPackages.validateConfigLints
        ];
        DOTFILES_REPO = "${self}";
      } ''
        validate-config-lints
        touch $out
      '';
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

      # Flake checks: scenario-based Nix tests + sandboxable shell lints.
      # Run all of them with: nix flake check
      checks.${defaultSystem} = scenarioChecks // {
        config-lints = configLintsCheck;
      };
    };
}
