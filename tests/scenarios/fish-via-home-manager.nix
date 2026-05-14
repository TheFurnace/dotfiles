# Asserts that fish is configured through Home Manager outputs rather than
# depending on a directly managed .config/fish tree.
#
# This validates the repo's explicit architectural constraint
# (documented in AGENTS.md):
#   programs.fish is enabled via Nix; .config/fish/ is intentionally absent
#   from the repo's .config/ tree so the configFilesFrom walk never touches it.
{ pkgs, lib, self, mkTestConfig }:
let
  cfg = (mkTestConfig { }).config;

  # Fish must be enabled through the Home Manager programs.fish module.
  fishEnabled = cfg.programs.fish.enable;

  # The repo must not have a .config/fish/ directory. If it did, the
  # configFilesFrom recursive walk in config-files.nix would pick it up
  # and lay it down alongside (or conflict with) the files that
  # programs.fish already manages.
  repoConfigDirs = builtins.attrNames (builtins.readDir "${self}/.config");
  repoHasFishDir = builtins.elem "fish" repoConfigDirs;

in
assert fishEnabled
  || builtins.throw
    "fish-via-home-manager: programs.fish.enable must be true, but it is false";
assert !repoHasFishDir
  || builtins.throw
    "fish-via-home-manager: .config/fish/ exists in the repo; fish must be configured via programs.fish in Nix, not via .config/fish/ files";
pkgs.runCommand "fish-via-home-manager" { } "touch $out"
