# This tracked fallback keeps `nixosConfigurations.default` evaluable in a
# fresh clone. Before activating it on a NixOS machine, replace this file with
# that machine's generated /etc/nixos/hardware-configuration.nix.
{ lib, ... }:
{
  # These low-priority values describe a conventional UEFI installation and
  # are intentionally easy for real hardware/host modules to override.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
