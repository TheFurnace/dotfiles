{ self, nix-index-database }:
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;

  configFilesFrom = relDir: prefix:
    let
      entries = builtins.readDir "${self}/.config/${relDir}";
      sourceFor = name:
        if cfg.mutable
        then config.lib.file.mkOutOfStoreSymlink
          "${cfg.localPath}/.config/${prefix}${name}"
        else "${self}/.config/${relDir}/${name}";
    in
    lib.foldl' (acc: name:
      let
        type = entries.${name};
      in
      if type == "regular"
      then acc // { "${prefix}${name}".source = sourceFor name; }
      else if type == "directory"
      then acc // (configFilesFrom "${relDir}/${name}" "${prefix}${name}/")
      else acc
    ) { } (builtins.attrNames entries);
in
{
  imports = [ nix-index-database.homeModules.nix-index ];

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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.mutable || cfg.localPath != "";
        message = "dotfiles.localPath must be set when dotfiles.mutable = true.";
      }
    ];

    home.username = lib.mkDefault cfg.username;
    home.homeDirectory = lib.mkDefault cfg.homeDirectory;

    # Helps downstream tools pick fish even outside NixOS.
    home.sessionVariables.SHELL = "${pkgs.fish}/bin/fish";

    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
      fish
      fira-code
      git
      kitty
      nix-your-shell
      oh-my-posh
    ];

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

      config.global = {
        hide_env_diff = true;
        warn_timeout = "30s";
      };
    };

    xdg.configFile =
      configFilesFrom "fish" "fish/" //
      configFilesFrom "git" "git/" //
      configFilesFrom "kitty" "kitty/" //
      configFilesFrom "nvim" "nvim/" //
      configFilesFrom "oh-my-posh" "oh-my-posh/" //
      {
        "fish/conf.d/direnv.fish".text = ''
          ${pkgs.direnv}/bin/direnv hook fish | source
        '';

        "fish/conf.d/nix-your-shell.fish".text = ''
          ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
        '';
      };

    home.activation.reportFishLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      current_shell="$(
        (command -v getent >/dev/null 2>&1 && getent passwd "${cfg.username}" | cut -d: -f7) || true
      )"

      if [ -n "$current_shell" ] \
        && [ "$current_shell" != "${pkgs.fish}/bin/fish" ] \
        && [ "$current_shell" != "/run/current-system/sw/bin/fish" ]; then
        echo "dotfiles: fish is installed and configured, but your login shell is still $current_shell"
        echo "dotfiles: on non-NixOS, run once: chsh -s \"$(command -v fish)\""
      fi
    '';
  };
}
