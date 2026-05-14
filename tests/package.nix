# Wraps tests/tests.py as an executable Nix package so it can be run with:
#
#   nix run .#packages.x86_64-linux.tests
#
{ flake, python3, writeShellApplication }:
writeShellApplication {
  name = "dotfiles-tests";
  runtimeInputs = [ python3 ];
  runtimeEnv = {
    # Ensure nix-command and flakes are available when the runner invokes nix.
    NIX_CONFIG = ''
      experimental-features = nix-command flakes
    '';
  };
  text = ''
    exec python3 ${flake}/tests/tests.py "$@"
  '';
}
