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
    in
    {
      # Public helpers for downstream flakes.
      lib = helperLib;

      # Public modules for direct consumption.
      homeManagerModules.default = homeModule;
      nixosModules.default = nixosModule;

      # Small built-in examples that also exercise the exported helpers.
      homeConfigurations.example = helperLib.mkHomeConfiguration {
        username = "demo";
        homeDirectory = "/home/demo";
        stateVersion = "25.11";
      };

      nixosConfigurations.example = helperLib.mkNixosConfiguration {
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
