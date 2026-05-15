# Registry of all nmt test cases.
# Each attribute name becomes the test identifier (with a "test-" prefix
# applied by the flake when exposing via legacyPackages).
{
  dotfiles-disabled = ./dotfiles-disabled.nix;
  dotfiles-config-files = ./dotfiles-config-files.nix;
  bash-nix-profile-path = ./bash-nix-profile-path.nix;
}
