{ self, nix-index-database }:
{ config, lib, pkgs, ... }:
let
  # Local shorthand for the module's option namespace.
  cfg = config.dotfiles;

  gitCompletionPwshSrc = pkgs.fetchFromGitHub {
    owner = "kzrnm";
    repo = "git-completion-pwsh";
    rev = "v1.4.0";
    hash = "sha256-0wc4ae731oT59gyplEnw92a8Ce1GaxmE9zqn/x7TA2U=";
  };

  # Recursively map files from this repo's .config tree into xdg.configFile.
  #
  # relDir tracks the source path below .config/ inside the flake.
  # prefix tracks the destination path below ~/.config/ for Home Manager.
  #
  # In immutable mode, sources come from the flake store path.
  # In mutable mode, sources become out-of-store symlinks into cfg.localPath so
  # edits to existing files are reflected immediately.
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
      # Ignore entries such as symlinks or special files. We only export the
      # regular files and directories that Home Manager can manage directly.
      else acc
    ) { } (builtins.attrNames entries);
in
{
  # nix-index-database replaces local nix-index generation, which is heavier
  # and unnecessary in this environment.
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

    # Allow callers to override these explicitly, while still making the
    # module self-contained by default.
    home.username = lib.mkDefault cfg.username;
    home.homeDirectory = lib.mkDefault cfg.homeDirectory;

    # Helps downstream tools pick fish even outside NixOS.
    home.sessionVariables.SHELL = "${pkgs.fish}/bin/fish";

    # Needed so GUI apps such as kitty can resolve configured fonts.
    fonts.fontconfig.enable = true;

    # Keep package installation centralized here; actual config files are
    # supplied from .config/ below.
    home.packages = with pkgs; [
      fish
      fira-code
      clang
      git
      just
      kitty
      ripgrep
      nix-your-shell
      oh-my-posh
      powershell
      zoxide
      gh
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

    # Treat .config/ in this repo as the canonical source of truth for config
    # file contents. New files are discovered on the next evaluation.
    xdg.configFile =
      configFilesFrom "fish" "fish/" //
      configFilesFrom "git" "git/" //
      configFilesFrom "kitty" "kitty/" //
      configFilesFrom "nvim" "nvim/" //
      configFilesFrom "oh-my-posh" "oh-my-posh/" //
      configFilesFrom "powershell" "powershell/" //
      {
        # These generated snippets wire package-provided shell hooks into fish
        # without handing ownership of fish/config.fish to Home Manager's
        # programs.fish module.
        "fish/conf.d/direnv.fish" = {
          force = true;
          text = ''
            ${pkgs.direnv}/bin/direnv hook fish | source
            ${pkgs.direnv}/bin/direnv export fish | source
          '';
        };

        "fish/conf.d/nix-your-shell.fish" = {
          force = true;
          text = ''
            ${pkgs.nix-your-shell}/bin/nix-your-shell fish | source
          '';
        };

        "fish/conf.d/zoxide.fish" = {
          force = true;
          text = ''
            ${pkgs.zoxide}/bin/zoxide init fish | source
          '';
        };
      };

    xdg.dataFile."powershell/Modules/git-completion" = {
      source = "${gitCompletionPwshSrc}/src";
      recursive = true;
    };

    # On non-NixOS platforms we cannot reliably change the account login shell
    # from Home Manager, so emit a one-time reminder after activation.
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
