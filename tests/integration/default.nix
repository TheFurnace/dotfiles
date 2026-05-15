# Registry of NixOS VM integration tests.
#
# These complement the nmt module tests under ../modules/ by exercising the
# real end-to-end flows (booting a VM, running the installer as a real user,
# inspecting activation side effects on disk).
#
# Each attribute is a derivation that the flake re-exports as
# `checks.<system>.<name>` so `nix flake check` runs them.
{ pkgs, self, home-manager, nixpkgs }:
{
  installer-bootstrap = import ./installer-bootstrap.nix {
    inherit pkgs self home-manager nixpkgs;
  };
}
