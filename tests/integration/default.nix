# Registry of host-side integration test runners. These are packages rather
# than checks because they must execute nested Nix operations through the host
# daemon after their closures have been built.
{ pkgs, self, home-manager, nixpkgs, nix-index-database }:
{
  installer-bootstrap = import ./installer-bootstrap.nix {
    inherit pkgs self home-manager nixpkgs nix-index-database;
  };
}
