# Minimal shared helpers for dotfiles scenario checks.
#
# Each helper builds a Home Manager configuration using the real dotfiles
# homeModule so that scenario tests exercise the module's actual behaviour
# rather than a hand-rolled stub.
{ nixpkgs, home-manager, homeModule }:
let
  defaultSystem = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${defaultSystem};

  # Standard test identity: memorable, not a real machine user.
  testUser = {
    username = "testuser";
    homeDirectory = "/home/testuser";
    stateVersion = "25.11";
  };

  # Build a Home Manager configuration for testing.
  # Accepts the same options as dotfiles.*; sensible defaults are applied.
  mkTestConfig =
    { mutable ? false
    , localPath ? ""
    , extraModules ? [ ]
    }:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        homeModule
        {
          dotfiles = {
            enable = true;
            inherit (testUser) username homeDirectory;
            inherit mutable localPath;
          };
          home.stateVersion = testUser.stateVersion;
        }
      ] ++ extraModules;
    };

in
{
  inherit pkgs testUser mkTestConfig;
}
