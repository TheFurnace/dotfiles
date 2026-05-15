# programs.bash is enabled by dotfiles, which means Home Manager owns
# ~/.bash_profile.  In standalone mode (no NixOS integration), that file
# must source the Nix profile script so that ~/.nix-profile/bin is present
# in PATH for login shells.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-files/.bash_profile

    # Single-user path must be sourced unconditionally (the guard is in the
    # shell snippet itself, not in Nix).
    grep -q 'nix-profile/etc/profile.d/nix\.sh' home-files/.bash_profile \
      || fail "~/.bash_profile does not source ~/.nix-profile/etc/profile.d/nix.sh"

    # The /etc/profile.d fallback for multi-user Nix installs must also be present.
    grep -q '/etc/profile\.d/nix\.sh' home-files/.bash_profile \
      || fail "~/.bash_profile does not source /etc/profile.d/nix.sh"
  '';
}
