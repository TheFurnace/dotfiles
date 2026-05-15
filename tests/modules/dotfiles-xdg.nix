# When dotfiles.enable = true the xdg module sets xdg.enable = true, which
# causes Home Manager to export the standard XDG base-directory variables in
# every session via hm-session-vars.sh.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-path/etc/profile.d/hm-session-vars.sh
    assertFileRegex home-path/etc/profile.d/hm-session-vars.sh 'XDG_CACHE_HOME'
    assertFileRegex home-path/etc/profile.d/hm-session-vars.sh 'XDG_CONFIG_HOME'
    assertFileRegex home-path/etc/profile.d/hm-session-vars.sh 'XDG_DATA_HOME'
    assertFileRegex home-path/etc/profile.d/hm-session-vars.sh 'XDG_STATE_HOME'
  '';
}
