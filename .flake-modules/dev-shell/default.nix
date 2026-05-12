{ nixpkgs, exampleHomeConfiguration }:
let
  defaultSystem = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${defaultSystem};
  validations = import ./validations.nix {
    inherit pkgs exampleHomeConfiguration;
  };
in
{
  devShells.${defaultSystem}.default = pkgs.mkShell {
    packages = with pkgs; [
      fish
      just
      kitty
      neovim
      nix
      nix-your-shell
      oh-my-posh
      powershell
      tree-sitter
      zoxide
    ] ++ validations.validationPackages;

    shellHook = ''
      export DOTFILES_REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      export DOTFILES_DEV_HOME="''${TMPDIR:-/tmp}/dotfiles-dev-shell"
      export HOME="$DOTFILES_DEV_HOME/home"
      export XDG_CONFIG_HOME="$DOTFILES_REPO/.config"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.cache"

      mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
      ln -snf "$DOTFILES_REPO/.config" "$HOME/.config"

      echo "dotfiles dev shell ready"
      echo "Validation commands: validate-fish-config, validate-neovim-config, validate-oh-my-posh-config, validate-kitty-config, validate-pwsh-config, validate-setup-script, validate-install-script, validate-dotfiles-config"
    '';
  };
}
