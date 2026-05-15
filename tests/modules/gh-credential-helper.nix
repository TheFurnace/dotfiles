# When dotfiles.enable = true the gh module enables programs.gh and
# registers gh as the git credential helper.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-files/.config/gh/config.yml
  '';
}
