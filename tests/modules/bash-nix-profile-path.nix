# Tests that $HOME/.nix-profile/bin is added to PATH for bash when using
# dotfiles with home-manager standalone.
#
# This test exercises the standalone-only code path (osConfig == null),
# where nix-installed tools need ~/.nix-profile/bin on PATH to be usable
# from a bash login shell without any system-level nix profile sourcing.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileContains home-files/.bash_profile ".nix-profile/bin"
  '';
}
