{ self, nix-index-database }:
{ ... }:
{
  imports = [
    ./options.nix
    ./base.nix
    (import ./packages.nix)
    (import ./programs.nix { inherit nix-index-database; })
    (import ./config-files.nix { inherit self; })
    (import ./data-files.nix { inherit self; })
    ./activation.nix
  ];
}
