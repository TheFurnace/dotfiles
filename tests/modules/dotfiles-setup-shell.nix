# When dotfiles.enable = true, the setup-shell module installs
# dotfiles-setup-shell into the Home Manager profile with this test's
# username/homeDirectory baked in as its defaults.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-path/bin/dotfiles-setup-shell
    assertFileRegex home-path/bin/dotfiles-setup-shell 'DOTFILES_USER:-test-user'
    assertFileRegex home-path/bin/dotfiles-setup-shell 'DOTFILES_HOME:-/home/test-user'
    assertFileContains home-path/bin/dotfiles-setup-shell "sudo dotfiles-setup-shell"

    # Exercise the installed binary directly (not just grep its source) to
    # confirm it's executable and that setup_shell's argument wiring works:
    # an unsupported shell name is rejected before any sudo/root check, so
    # this can run unprivileged in the test sandbox.
    if output=$("$(_abs home-path/bin/dotfiles-setup-shell)" "not-a-real-shell" 2>&1); then
      echo "expected dotfiles-setup-shell to reject an unsupported shell" >&2
      exit 1
    fi
    echo "$output" | grep -q "unsupported shell 'not-a-real-shell'"
  '';
}
