# When dotfiles.enable = true each interactive shell emits OSC 9;9 so that
# Windows Terminal can track the current working directory.
{
  dotfiles.enable = true;

  nmt.script = ''
    # bash: PROMPT_COMMAND hook must be present in the generated .bashrc
    assertFileContains home-files/.bashrc "__update_cwd_osc"
    assertFileContains home-files/.bashrc "PROMPT_COMMAND"

    # fish: --on-event fish_prompt handler must be in the generated config.fish
    assertFileContains home-files/.config/fish/config.fish "__update_cwd_osc"
    assertFileContains home-files/.config/fish/config.fish "fish_prompt"

    # pwsh: prompt wrapper must be present in the linked profile
    assertFileContains home-files/.config/powershell/Microsoft.PowerShell_profile.ps1 "__prevPrompt"
    assertFileContains home-files/.config/powershell/Microsoft.PowerShell_profile.ps1 "9;9;"
  '';
}
