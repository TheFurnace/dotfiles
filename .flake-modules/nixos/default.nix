{ home-manager, homeModule }:
{ ... }:
{
  imports = [
    ./options.nix
    ./system-integration.nix
    (import ./home-manager.nix { inherit home-manager homeModule; })
  ];
}
