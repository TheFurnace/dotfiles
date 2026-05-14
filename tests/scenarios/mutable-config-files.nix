# Validates that .config entries use the mutable/out-of-store path behaviour
# when localPath is supplied. In mutable mode each source should be the
# derivation produced by mkOutOfStoreSymlink (an attribute set), not a plain
# store-path string, so that edits to existing files take effect immediately
# without a rebuild.
{ pkgs, lib, mkTestConfig, testUser }:
let
  localPath = "/tmp/test-dotfiles-local";
  cfg = (mkTestConfig { mutable = true; inherit localPath; }).config;
  configFiles = cfg.xdg.configFile;

  # These entries must be present and must use mkOutOfStoreSymlink (i.e. be
  # derivations) rather than plain store-path strings.
  sampleEntries = [ "kitty/kitty.conf" "git/config" ];

  nonDerivationSources = lib.filter
    (e: configFiles ? ${e} && !(lib.isDerivation configFiles.${e}.source))
    sampleEntries;

in
assert nonDerivationSources == [ ]
  || builtins.throw
    "mutable-config-files: expected mkOutOfStoreSymlink derivations in mutable mode, but got plain paths for: ${lib.concatStringsSep ", " nonDerivationSources}";
pkgs.runCommand "mutable-config-files" { } "touch $out"
