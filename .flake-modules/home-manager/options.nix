{ lib, ... }:
{
  options.dotfiles = {
    enable = lib.mkEnableOption "plug-and-play dotfiles environment";

    username = lib.mkOption {
      type = lib.types.str;
      description = "The home-manager user. Sets home.username.";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the user's home directory. Sets home.homeDirectory.";
    };

    mutable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When false (default), config files are copied from the Nix store.
        A rebuild is required to pick up any change.

        When true, config files are live symlinks pointing into
        localPath. Edits to existing files take effect immediately
        (for example after `exec fish`); adding or removing files still
        requires a rebuild so the symlink set can be updated.
      '';
    };

    localPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Absolute path to the local dotfiles checkout.
        Required, and only used, when mutable = true.
      '';
    };
  };
}
