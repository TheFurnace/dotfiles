# Backward-compatible wrapper around the concern-oriented Home Manager module
# layout under ./.flake-modules/home-manager/.
{ self, nix-index-database }:
import ./home-manager {
  inherit self nix-index-database;
}
