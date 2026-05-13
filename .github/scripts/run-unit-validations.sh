#!/usr/bin/env bash
# Run repository flake/unit validations with explicit PASS/FAIL output per check.

set -euo pipefail

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

run_check "flake check" nix flake check
run_validation() {
  local label="$1"
  local shell_name="$2"
  local command_name="$3"

  echo "==> $label"
  if nix develop ".#${shell_name}" --command bash -lc "set -euo pipefail; ${command_name}"; then
    echo "PASS: $label"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $label"
    fail_count=$((fail_count + 1))
  fi
  echo
}

run_validation "validate fish config" fish validate-fish-config
run_validation "validate neovim config" neovim validate-neovim-config
run_validation "validate oh-my-posh config" oh-my-posh validate-oh-my-posh-config
run_validation "validate kitty config" kitty validate-kitty-config
run_validation "validate powershell config" powershell validate-pwsh-config
run_validation "validate setup script" scripts validate-setup-script
run_validation "validate install script" scripts validate-install-script
run_validation "validate full dotfiles config" validation validate-dotfiles-config

echo "Validation summary: $pass_count passed, $fail_count failed."

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
