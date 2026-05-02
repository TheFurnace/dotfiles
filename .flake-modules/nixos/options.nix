{ lib, ... }:
{
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
}
