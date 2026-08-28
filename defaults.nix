# Repository-local identity and host defaults.
#
# Edit this file after cloning when the checkout is for another user or host.
# The reusable modules and constructors under ./.flake-modules remain generic;
# these values only feed the built-in `homeConfigurations.default` and
# `nixosConfigurations.default` outputs.
{
  system = "x86_64-linux";

  username = "ferndq";
  homeDirectory = "/home/ferndq";
  hostname = "nixos";

  # Keep these at the release used for the first installation. Do not bump
  # them merely because the flake inputs are updated.
  homeStateVersion = "25.11";
  nixosStateVersion = "25.11";

  # Standalone Home Manager customizations can be added here without changing
  # flake.nix. Paths are resolved relative to this file.
  homeModules = [ ];

  # Replace nixos/hardware-configuration.nix with the file generated for the
  # target machine before activating the NixOS configuration.
  nixosModules = [
    ./nixos/hardware-configuration.nix
  ];
}
