# programs.bash is enabled by dotfiles, which means Home Manager owns
# ~/.bash_profile.  In standalone mode (no NixOS integration), that file
# must source the Nix profile script so that ~/.nix-profile/bin is present
# in PATH for login shells.
#
# Home Manager's bash module places profileExtra in ~/.profile, which
# ~/.bash_profile sources unconditionally.
{
  dotfiles.enable = true;

  nmt.script = ''
    # Confirm Home Manager is managing both files.
    assertFileExists home-files/.bash_profile
    assertFileExists home-files/.profile

    # ~/.bash_profile must delegate to ~/.profile (HM's standard wiring).
    assertFileContains home-files/.bash_profile '. ~/.profile'

    # ~/.profile must source the single-user Nix profile path.
    assertFileContains home-files/.profile '$HOME/.nix-profile/etc/profile.d/nix.sh'

    # ~/.profile must also include the /etc/profile.d fallback for multi-user
    # Nix installs.
    assertFileContains home-files/.profile '/etc/profile.d/nix.sh'
  '';
}
