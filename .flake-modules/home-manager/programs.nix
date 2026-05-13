{ nix-index-database }:
{ config, lib, osConfig ? null, pkgs, ... }:
let
  cfg = config.dotfiles;
  isStandaloneHomeManager = osConfig == null;
in
{
  # nix-index-database replaces local nix-index generation, which is heavier
  # and unnecessary in this environment.
  imports = [ nix-index-database.homeModules.nix-index ];

  config = lib.mkIf cfg.enable {
    programs.home-manager = lib.mkIf isStandaloneHomeManager {
      enable = true;
    };

    programs.bash = {
      enable = true;
      initExtra = ''
        if [ -f ~/.config/oh-my-posh/themes/lambda.omp.json ]; then
          eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init bash --config ~/.config/oh-my-posh/themes/lambda.omp.json)"
        fi

        source <(${pkgs.nix-your-shell}/bin/nix-your-shell bash)
      '';
    };

    programs.nix-index-database.comma.enable = true;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableFishIntegration = true;

      config.global = {
        hide_env_diff = true;
        warn_timeout = "30s";
      };
    };

    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
