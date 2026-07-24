# Pi is bootstrapped with its official installer while tmux remains a
# declaratively managed Home Manager package.
{ pkgs, ... }:
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-path/bin/tmux
    assertFileRegex activate 'installPi'
    assertFileContains activate 'https://pi.dev/install.sh'
    assertFileContains activate '/home/test-user/.local/bin/pi'
    assertFileContains activate '${pkgs.curl}/bin/curl'
    assertFileContains activate '${pkgs.bash}/bin/sh'
  '';
}
