{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  config = lib.mkIf cfg.enable {
    # Keep Home Manager profile bins available in standalone fish login shells
    # without enabling programs.fish.
    #
    # The path list intentionally covers common user/system Nix profile layouts
    # across standalone Home Manager and NixOS; nonexistent directories are
    # skipped at runtime.
    xdg.configFile."fish/conf.d/00-home-manager-path.fish" = {
      force = true;
      text = ''
        for profile_bin in "$HOME/.nix-profile/bin" "/etc/profiles/per-user/$USER/bin" "/nix/var/nix/profiles/default/bin"
            if test -d "$profile_bin"
                fish_add_path --move --prepend "$profile_bin"
            end
        end
      '';
    };
  };
}
