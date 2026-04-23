{ home-manager, homeModule }:
{ config, lib, pkgs, ... }:
let
  # Local shorthand for the NixOS-facing option namespace.
  cfg = config.dotfiles;

  # Let callers override the home path explicitly, but keep a predictable
  # default for typical systems.
  effectiveHomeDirectory =
    if cfg.homeDirectory != null then cfg.homeDirectory
    else "/home/${cfg.username}";
in
{
  # The NixOS module is intentionally thin: it delegates user-space setup to
  # the Home Manager module and only handles system integration here.
  imports = [ home-manager.nixosModules.home-manager ];

  options.dotfiles = {
    enable = lib.mkEnableOption "plug-and-play dotfiles environment";

    username = lib.mkOption {
      type = lib.types.str;
      description = "The NixOS user that should receive this Home Manager configuration.";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional home directory override. Defaults to /home/<name>. If your NixOS user uses a different home path, set this explicitly.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "Home Manager state version for the managed user.";
    };

    mutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Forwarded to the Home Manager module.";
    };

    localPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Forwarded to the Home Manager module when mutable = true.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure fish exists both as a managed package and as a valid login shell
    # from the system's perspective.
    programs.fish.enable = true;
    environment.shells = [ pkgs.fish ];

    # Fill in the user home and shell if the surrounding NixOS config did not
    # already set them more specifically.
    users.users.${cfg.username} = {
      home = lib.mkDefault effectiveHomeDirectory;
      shell = pkgs.fish;
    };

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
