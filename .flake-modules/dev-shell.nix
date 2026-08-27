# Backward-compatible wrapper around the concern-oriented dev-shell module
# layout under ./.flake-modules/dev-shell/.
{ nixpkgs, supportedSystems }:
import ./dev-shell {
  inherit nixpkgs supportedSystems;
}
