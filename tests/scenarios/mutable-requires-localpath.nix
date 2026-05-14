# Asserts that enabling dotfiles.mutable = true without setting dotfiles.localPath
# causes the expected module assertion to fail.
#
# This validates the option contract declared in
# .flake-modules/home-manager/base.nix:
#
#   assertion = !cfg.mutable || cfg.localPath != "";
#   message   = "dotfiles.localPath must be set when dotfiles.mutable = true.";
#
# Accessing any config attribute on a module with a failing assertion triggers
# a builtins.throw from the module system. We use builtins.tryEval to catch
# that throw and verify the assertion contract is wired up correctly.
{ pkgs, lib, mkTestConfig }:
let
  # Attempt to evaluate the bad config; the module system should throw.
  result = builtins.tryEval (
    # Force the chain: building the activation package triggers assertion checking.
    (mkTestConfig { mutable = true; localPath = ""; }).activationPackage.outPath
  );

in
assert !result.success
  || builtins.throw
    "mutable-requires-localpath: expected a module assertion failure when mutable=true and localPath is empty, but evaluation succeeded";
pkgs.runCommand "mutable-requires-localpath" { } "touch $out"
