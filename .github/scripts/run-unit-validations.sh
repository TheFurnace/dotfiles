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
run_check \
  "validate full dotfiles config" \
  nix develop .#default --command bash -lc "set -euo pipefail; validate-dotfiles-config"

echo "Validation summary: $pass_count passed, $fail_count failed."

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
