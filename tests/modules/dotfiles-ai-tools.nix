# Stable AI dependencies and the manager are declarative. The mutable agent
# binaries are never downloaded as a Home Manager activation side effect.
{
  dotfiles.enable = true;

  nmt.script = ''
    assertFileExists home-path/bin/tmux
    assertFileExists home-path/bin/jq
    assertFileExists home-path/bin/python3
    assertFileExists home-path/bin/dotfiles-ai
    assertFileContains home-path/bin/dotfiles-ai 'https://pi.dev/install.sh'
    assertFileContains home-path/bin/dotfiles-ai 'https://chatgpt.com/codex/install.sh'
    assertFileContains home-path/bin/dotfiles-ai 'update_pi'
    assertFileContains home-path/bin/dotfiles-ai 'update_codex'

    if grep -qE 'pi.dev/install.sh|chatgpt.com/codex/install.sh' "$TESTED/activate"; then
      echo "AI installers must not run during Home Manager activation" >&2
      exit 1
    fi
  '';
}
