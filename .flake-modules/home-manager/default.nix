{ self, nix-index-database }:
{ ... }:
{
  imports = [
    ./options.nix
    ./base.nix
    ./xdg.nix
    (import ./packages.nix)
    (import ./programs.nix { inherit nix-index-database; })
    ./gh.nix
    ./fish
    (import ./config-files.nix { inherit self; })
    (import ./data-files.nix { inherit self; })
    ./activation.nix
  ];
}
