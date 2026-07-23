# Registry of all nmt test cases.
# Each attribute name becomes the test identifier (with a "test-" prefix
# applied by the flake when exposing via legacyPackages).
{
  dotfiles-disabled = ./dotfiles-disabled.nix;
  dotfiles-config-files = ./dotfiles-config-files.nix;
  dotfiles-git = ./dotfiles-git.nix;
  dotfiles-osc-9-9 = ./dotfiles-osc-9-9.nix;
  dotfiles-setup-shell = ./dotfiles-setup-shell.nix;
  dotfiles-xdg = ./dotfiles-xdg.nix;
  gh-credential-helper = ./gh-credential-helper.nix;
}
