{ nixpkgs, exampleHomeConfiguration }:
let
  defaultSystem = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${defaultSystem};
  validations = import ./validations.nix {
    inherit pkgs exampleHomeConfiguration;
  };
  commonShellHook = ''
    export DOTFILES_REPO="$(command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel 2>/dev/null || pwd)"
    export DOTFILES_DEV_HOME="''${TMPDIR:-/tmp}/dotfiles-dev-shell"
    export HOME="$DOTFILES_DEV_HOME/home"
    export XDG_CONFIG_HOME="$DOTFILES_REPO/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"

    ${pkgs.coreutils}/bin/mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
    ${pkgs.coreutils}/bin/ln -snf "$DOTFILES_REPO/.config" "$HOME/.config"
  '';
  mkDotfilesShell = name: packages:
    pkgs.mkShell {
      inherit packages;

      shellHook = commonShellHook + ''
        echo "dotfiles dev shell ready (${name})"
      '';
    };
in
{
  devShells.${defaultSystem} = {
    default = mkDotfilesShell "default" (with pkgs; [
      just
      nix
    ]);

    fish = mkDotfilesShell "fish" (with pkgs; [
      fish
      nix-your-shell
      oh-my-posh
      zoxide
      validations.validationPackages.validateFishConfig
    ]);

    neovim = mkDotfilesShell "neovim" (with pkgs; [
      neovim
      tree-sitter
      validations.validationPackages.validateNeovimConfig
    ]);

    oh-my-posh = mkDotfilesShell "oh-my-posh" (with pkgs; [
      oh-my-posh
      validations.validationPackages.validateOhMyPoshConfig
    ]);

    kitty = mkDotfilesShell "kitty" (with pkgs; [
      kitty
      validations.validationPackages.validateKittyConfig
    ]);

    powershell = mkDotfilesShell "powershell" (with pkgs; [
      oh-my-posh
      powershell
      zoxide
      validations.validationPackages.validatePwshConfig
    ]);

    scripts = mkDotfilesShell "scripts" (with pkgs; [
      bash
      nix
      validations.validationPackages.validateInstallScript
      validations.validationPackages.validateSetupScript
    ]);

    validation = mkDotfilesShell "validation" (with pkgs; [
      validations.validationPackages.validateDotfilesConfig
    ]);
  };
}
