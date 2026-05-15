{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    # Ensure XDG_CACHE_HOME, XDG_CONFIG_HOME, XDG_DATA_HOME, and
    # XDG_STATE_HOME are exported in every session.
    xdg.enable = true;
  };
}
