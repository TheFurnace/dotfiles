#!/usr/bin/env bash

set -uo pipefail

pass_count=0
fail_count=0

run_check() {
  local label="$1"
  shift

  echo "==> $label"
  if "$@"; then
    echo "PASS: $label"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $label"
    fail_count=$((fail_count + 1))
  fi
  echo
}

run_devshell_check() {
  local label="$1"
  local validation_command="$2"
  run_check "$label" nix develop .#default --command bash -lc "$validation_command"
}

run_check "flake check" nix flake check
run_devshell_check "validate fish config" "validate-fish-config"
run_devshell_check "validate neovim config" "validate-neovim-config"
run_devshell_check "validate oh-my-posh config" "validate-oh-my-posh-config"
run_devshell_check "validate kitty config" "validate-kitty-config"
run_devshell_check "validate powershell config" "validate-pwsh-config"
run_devshell_check "validate setup script" "validate-setup-script"
run_devshell_check "validate install script" "validate-install-script"

echo "Validation summary: $pass_count passed, $fail_count failed."

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
