# Pi is bootstrapped with its official installer while its terminal
# dependencies remain declaratively managed Home Manager packages.
{ pkgs, ... }:
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-path/bin/tmux
    assertFileExists home-path/bin/jq
    assertFileExists home-path/bin/python3
    assertFileRegex activate 'installPi'
    assertFileContains activate 'https://pi.dev/install.sh'
    assertFileContains activate '/home/test-user/.local/bin/pi'
    assertFileContains activate '${pkgs.curl}/bin/curl'
    assertFileContains activate '${pkgs.bash}/bin/sh'
  '';
}
