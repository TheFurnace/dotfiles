# Ensures the documented .#example configuration evaluates and builds.
#
# This exercises the full homeConfigurations.example flake output, including
# module imports, package declarations, and the .config/ recursive discovery.
{ exampleHomeConfiguration }:
exampleHomeConfiguration.activationPackage
