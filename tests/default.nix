# Aggregates scenario-based checks for the dotfiles flake.
#
# Returns an attrset of check-name -> derivation suitable for
# flake outputs.checks.<system>.
{ pkgs, lib, self, nixpkgs, home-manager, homeModule, helperLib, exampleHomeConfiguration }:
let
  testLib = import ./lib.nix { inherit nixpkgs home-manager homeModule; };
in
{
  "example-build" = import ./scenarios/example-build.nix {
    inherit exampleHomeConfiguration;
  };

  "standalone-lib-build" = import ./scenarios/standalone-lib-build.nix {
    inherit helperLib;
  };

  "immutable-config-files" = import ./scenarios/immutable-config-files.nix {
    inherit pkgs lib;
    inherit (testLib) mkTestConfig;
  };

  "mutable-config-files" = import ./scenarios/mutable-config-files.nix {
    inherit pkgs lib;
    inherit (testLib) mkTestConfig testUser;
  };

  "mutable-requires-localpath" = import ./scenarios/mutable-requires-localpath.nix {
    inherit pkgs lib;
    inherit (testLib) mkTestConfig;
  };

  "fish-via-home-manager" = import ./scenarios/fish-via-home-manager.nix {
    inherit pkgs lib self;
    inherit (testLib) mkTestConfig;
  };
}
