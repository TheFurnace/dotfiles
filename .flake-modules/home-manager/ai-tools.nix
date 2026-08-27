# Pi and Codex intentionally stay outside the Nix store so their upstream
# update mechanisms can move independently from the flake lock. Nix owns the
# stable runtime dependencies and this explicit installer/updater interface.
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;

  dotfilesAi = pkgs.writeShellApplication {
    name = "dotfiles-ai";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.curl pkgs.findutils ];
    text = ''
      usage() {
        echo "Usage: dotfiles-ai <install|update|status> [pi|codex|all]"
      }

      find_pi() {
        if command -v pi >/dev/null 2>&1; then
          command -v pi
          return 0
        fi
        if [ -x "$HOME/.local/bin/pi" ]; then
          printf '%s\n' "$HOME/.local/bin/pi"
          return 0
        fi
        for candidate in "$HOME/.local/share/pi-node/"*/bin/pi; do
          if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
          fi
        done
        return 1
      }

      find_codex() {
        if command -v codex >/dev/null 2>&1; then
          command -v codex
          return 0
        fi
        if [ -x "$HOME/.local/bin/codex" ]; then
          printf '%s\n' "$HOME/.local/bin/codex"
          return 0
        fi
        return 1
      }

      install_pi() {
        if pi_bin="$(find_pi)"; then
          echo "Pi is already installed at $pi_bin"
        else
          echo "Installing Pi from pi.dev"
          curl -fsSL https://pi.dev/install.sh | bash
        fi
      }

      update_pi() {
        if pi_bin="$(find_pi)"; then
          "$pi_bin" update
        else
          install_pi
        fi
      }

      install_codex() {
        if codex_bin="$(find_codex)"; then
          echo "Codex is already installed at $codex_bin"
        else
          echo "Installing Codex from chatgpt.com"
          curl -fsSL https://chatgpt.com/codex/install.sh | bash
        fi
      }

      update_codex() {
        echo "Installing or updating Codex from chatgpt.com"
        curl -fsSL https://chatgpt.com/codex/install.sh | bash
      }

      status_one() {
        case "$1" in
          pi)
            if pi_bin="$(find_pi)"; then
              echo "pi: installed ($pi_bin)"
            else
              echo "pi: not installed"
            fi
            ;;
          codex)
            if codex_bin="$(find_codex)"; then
              echo "codex: installed ($codex_bin)"
            else
              echo "codex: not installed"
            fi
            ;;
        esac
      }

      action="''${1:-}"
      target="''${2:-all}"
      case "$action" in
        install | update | status) ;;
        *) usage; exit 1 ;;
      esac
      case "$target" in
        pi | codex | all) ;;
        *) usage; exit 1 ;;
      esac

      for tool in pi codex; do
        if [ "$target" != "all" ] && [ "$target" != "$tool" ]; then
          continue
        fi
        case "$action:$tool" in
          install:pi) install_pi ;;
          install:codex) install_codex ;;
          update:pi) update_pi ;;
          update:codex) update_codex ;;
          status:*) status_one "$tool" ;;
        esac
      done
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.features.aiTools.enable) {
    home.packages = with pkgs; [
      dotfilesAi
      jq
      python3
      tmux
    ];
  };
}
