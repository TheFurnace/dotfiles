# Validates that representative .config entries are materialised in the expected
# way for immutable mode: each source should be a plain store-path string taken
# directly from the flake, not a derivation (mkOutOfStoreSymlink produces a
# derivation; a direct store copy does not).
{ pkgs, lib, mkTestConfig }:
let
  cfg = (mkTestConfig { }).config;
  configFiles = cfg.xdg.configFile;

  # Representative entries that the .config/ recursive walk must produce.
  expectedEntries = [
    "git/config"
    "kitty/kitty.conf"
    "nvim/init.lua"
    "oh-my-posh/themes/lambda.omp.json"
  ];

  missingEntries = builtins.filter (e: !(configFiles ? ${e})) expectedEntries;

  # In immutable mode the source is a plain string (store path), not a derivation.
  # mkOutOfStoreSymlink would return an attribute set (derivation); we assert that
  # none of the expected entries have that form here.
  derivationSources = lib.filter
    (e: configFiles ? ${e} && lib.isDerivation configFiles.${e}.source)
    expectedEntries;

in
assert missingEntries == [ ]
  || builtins.throw
    "immutable-config-files: missing xdg.configFile entries: ${lib.concatStringsSep ", " missingEntries}";
assert derivationSources == [ ]
  || builtins.throw
    "immutable-config-files: expected plain store-path sources in immutable mode, but got derivations for: ${lib.concatStringsSep ", " derivationSources}";
pkgs.runCommand "immutable-config-files" { } "touch $out"
