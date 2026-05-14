# When dotfiles.enable = true the config-files module wires every file under
# .config/ into xdg.configFile, which places them in the activation package
# at home-files/.config/<path>.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-files/.config/git/config
    assertFileExists home-files/.config/nvim/init.lua
    assertFileExists home-files/.config/kitty/kitty.conf
    assertFileExists home-files/.config/oh-my-posh/themes/lambda.omp.json
  '';
}
