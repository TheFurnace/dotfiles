# Ensures a minimal consumer configuration built via dotfiles.lib.mkHomeConfiguration
# evaluates and builds. This validates the advertised public API and the standalone
# consumption path documented in the README.
{ helperLib }:
(helperLib.mkHomeConfiguration {
  username = "consumer";
  homeDirectory = "/home/consumer";
  stateVersion = "25.11";
}).activationPackage
