# Backward-compatible wrapper around the concern-oriented NixOS module layout
# under ./.flake-modules/nixos/.
{ home-manager, homeModule }:
import ./nixos {
  inherit home-manager homeModule;
}
