# Optional feature groups make the same core useful on headless/minimal Linux
# systems without forking the module.
{
  dotfiles = {
    enable = true;
    features = {
      desktop.enable = false;
      development.enable = false;
      aiTools.enable = false;
    };
  };

  nmt.script = ''
    assertFileExists home-path/bin/git
    assertFileExists home-path/bin/nvim
    assertFileExists home-path/bin/rg
    assertPathNotExists home-path/bin/kitty
    assertPathNotExists home-path/bin/pwsh
    assertPathNotExists home-path/bin/gh
    assertPathNotExists home-path/bin/dotfiles-ai
  '';
}
