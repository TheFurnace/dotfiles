# End-to-end VM test for the `nix run github:TheFurnace/dotfiles -- init` installer.
#
# Exercises the actual user-facing bootstrap flow:
#
#   1. boot a NixOS VM (shared base module + alice user from ./lib.nix)
#   2. run the installer as alice with DOTFILES_URL / DOTFILES_NIXPKGS_URL /
#      DOTFILES_HOME_MANAGER_URL pointed at the local store paths of this
#      flake's own inputs so the written flake locks reproducibly
#   3. assert that the flake was written to $XDG_CONFIG_HOME/home-manager/
#   4. assert that Home Manager activation produced the expected profile,
#      gcroot, and config-file symlinks
#   5. re-run the installer and confirm idempotent behaviour
#
# To run directly:
#
#   nix build .#checks.x86_64-linux.installer-bootstrap
#
{ pkgs, self, home-manager, nixpkgs }:

let
  helpers = import ./lib.nix { inherit pkgs self home-manager nixpkgs; };
  inherit (helpers) makeTest baseModule aliceModule system;

  # Pre-build the Home Manager activation package that the installer will
  # construct inside the VM. Seeding its closure into the VM avoids the
  # majority of substituter traffic when the installer runs — anything the
  # in-VM evaluation derives that doesn't already exist in this closure can
  # still be fetched from the default substituter via NAT.
  aliceHomeConfig = self.lib.mkHomeConfiguration {
    inherit system;
    username = "alice";
    homeDirectory = "/home/alice";
    stateVersion = "25.11";
  };
in
makeTest {
  name = "dotfiles-installer-bootstrap";

  nodes.machine = { ... }: {
    imports = [ baseModule aliceModule ];

    # Append the pre-built alice activation package so the bulk of the
    # closure is already in the VM store before activation runs.
    system.extraDependencies = [ aliceHomeConfig.activationPackage ];
  };

  testScript = ''
    import shlex

    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    def alice_cmd(cmd):
        # `su -l` starts a login shell so XDG_RUNTIME_DIR and the user bus
        # are wired up the same way an interactive login would.
        return "su -l alice -c " + shlex.quote(cmd)

    def succeed_as_alice(cmd):
        return machine.succeed(alice_cmd(cmd))

    installer_env = (
        "DOTFILES_URL=path:${self} "
        "DOTFILES_NIXPKGS_URL=path:${nixpkgs} "
        "DOTFILES_HOME_MANAGER_URL=path:${home-manager} "
        "DOTFILES_USER=alice "
        "DOTFILES_HOME=/home/alice "
        "DOTFILES_STATE_VERSION=25.11"
    )

    with subtest("nix run installer completes successfully"):
        succeed_as_alice(f"{installer_env} nix run dotfiles -- init --switch")

    with subtest("Home Manager flake was written to XDG config home"):
        machine.succeed(
            "test -f /home/alice/.config/home-manager/flake.nix"
        )

    with subtest("Home Manager profile and gcroot exist"):
        machine.succeed(
            "test -e /home/alice/.local/state/nix/profiles/home-manager"
        )
        machine.succeed(
            "test -L /home/alice/.local/state/home-manager/gcroots/current-home"
        )

    with subtest("dotfiles config files are linked into alice's home"):
        # Fish is enabled via programs.fish in the dotfiles Home Manager
        # module, so its config should be present even though .config/fish/
        # isn't in the repo.
        succeed_as_alice("test -e /home/alice/.config/fish/config.fish")
        # These come from .config/ in the repo via the config-files module.
        succeed_as_alice("test -L /home/alice/.config/git/config")
        succeed_as_alice("test -L /home/alice/.config/nvim/init.lua")
        succeed_as_alice("test -L /home/alice/.config/kitty/kitty.conf")
        succeed_as_alice(
            "test -L /home/alice/.config/oh-my-posh/themes/lambda.omp.json"
        )

    with subtest("a package from packages.nix is available on PATH"):
        # ripgrep is listed in .flake-modules/home-manager/packages.nix and
        # should be linked into the user's nix profile after activation.
        succeed_as_alice("test -x /home/alice/.nix-profile/bin/rg")

    with subtest("installer is idempotent on a second run"):
        first_gen = machine.succeed(
            "readlink /home/alice/.local/state/home-manager/gcroots/current-home"
        ).strip()
        succeed_as_alice(f"{installer_env} nix run dotfiles -- init --switch")
        second_gen = machine.succeed(
            "readlink /home/alice/.local/state/home-manager/gcroots/current-home"
        ).strip()
        assert first_gen == second_gen, (
            "current-home gcroot changed across idempotent runs: "
            f"{first_gen!r} -> {second_gen!r}"
        )
  '';
}
