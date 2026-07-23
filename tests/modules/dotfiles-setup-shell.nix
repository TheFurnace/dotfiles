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
  '';
}
