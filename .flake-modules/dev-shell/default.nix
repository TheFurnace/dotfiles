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
    default = mkDotfilesShell "validation" (with pkgs; [
      nix
      validations.validationPackages.validateDotfilesConfig
    ]);
  };
}
