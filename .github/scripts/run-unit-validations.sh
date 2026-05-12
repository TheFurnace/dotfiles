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
if nix develop .#default --command bash -lc '
  set -uo pipefail
  fail_count=0

  run_validation() {
    local label="$1"
    local command_name="$2"

    echo "==> $label"
    if "$command_name"; then
      echo "PASS: $label"
    else
      echo "FAIL: $label"
      fail_count=$((fail_count + 1))
    fi
    echo
  }

  run_validation "validate fish config" validate-fish-config
  run_validation "validate neovim config" validate-neovim-config
  run_validation "validate oh-my-posh config" validate-oh-my-posh-config
  run_validation "validate kitty config" validate-kitty-config
  run_validation "validate powershell config" validate-pwsh-config
  run_validation "validate setup script" validate-setup-script
  run_validation "validate install script" validate-install-script

  if [ "$fail_count" -gt 0 ]; then
    exit 1
  fi
'; then
  pass_count=$((pass_count + 1))
else
  fail_count=$((fail_count + 1))
fi

echo "Validation summary: $pass_count passed, $fail_count failed."

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
