# Backward-compatible wrapper around the concern-oriented dev-shell module
# layout under ./.flake-modules/dev-shell/.
{ nixpkgs, exampleHomeConfiguration }:
import ./dev-shell {
  inherit nixpkgs exampleHomeConfiguration;
}
