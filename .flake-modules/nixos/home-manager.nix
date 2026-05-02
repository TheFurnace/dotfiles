{ home-manager, homeModule }:
{ config, lib, ... }:
let
  cfg = config.dotfiles;

  effectiveHomeDirectory =
    if cfg.homeDirectory != null then cfg.homeDirectory
    else "/home/${cfg.username}";
in
{
  # The NixOS module is intentionally thin: it delegates user-space setup to
  # the Home Manager module and only handles system integration here.
  imports = [ home-manager.nixosModules.home-manager ];

  config = lib.mkIf cfg.enable {
    # Reuse the system pkgs set so Home Manager and NixOS stay aligned.
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.${cfg.username} = {
      # Reuse the standalone Home Manager module rather than duplicating any
      # package or file-management logic here.
      imports = [ homeModule ];

      dotfiles = {
        enable = true;
        username = cfg.username;
        homeDirectory = effectiveHomeDirectory;
        mutable = cfg.mutable;
        localPath = cfg.localPath;
      };

      home.stateVersion = cfg.stateVersion;
    };
  };
}
