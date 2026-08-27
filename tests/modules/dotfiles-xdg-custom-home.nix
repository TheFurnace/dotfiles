# Shell integrations must use Home Manager's resolved XDG config path rather
# than assuming ~/.config.
{
  dotfiles.enable = true;
  xdg.configHome = "/home/test-user/.xdg-config";

  nmt.script = ''
    assertFileExists home-files/.xdg-config/fish/config.fish
    assertFileContains home-files/.xdg-config/fish/config.fish \
      '/home/test-user/.xdg-config/oh-my-posh/themes/lambda.omp.json'
    assertFileContains home-files/.bashrc \
      '/home/test-user/.xdg-config/oh-my-posh/themes/lambda.omp.json'
  '';
}
