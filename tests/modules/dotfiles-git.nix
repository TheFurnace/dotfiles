# When dotfiles.enable = true the programs.git module writes the git config
# with all aliases and core settings to home-files/.config/git/config.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-files/.config/git/config
    assertFileContains home-files/.config/git/config "adog"
    assertFileContains home-files/.config/git/config 'editor = "nvim"'
  '';
}
