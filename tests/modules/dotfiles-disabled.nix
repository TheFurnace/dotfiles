# When dotfiles.enable = false (the default in baseTestModule), no config
# files managed by the module should appear in the activation package.
{
  nmt.script = ''
    assertPathNotExists home-files/.config/git
    assertPathNotExists home-files/.config/nvim
    assertPathNotExists home-files/.config/kitty
    assertPathNotExists home-files/.config/oh-my-posh
    assertPathNotExists home-path/bin/dotfiles-setup-shell
  '';
}
