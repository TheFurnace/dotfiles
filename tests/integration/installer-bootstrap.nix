# End-to-end VM test for the `nix run github:TheFurnace/dotfiles` installer.
#
# Exercises the actual user-facing bootstrap flow:
#
#   1. boot a NixOS VM (shared base module + alice user from ./lib.nix)
#   2. run `nix run dotfiles` as alice — the installer's flake registry
#      alias resolves to the local checkout
#   3. assert that Home Manager activation produced the expected profile,
#      gcroot, and config-file symlinks
#   4. re-run the installer and confirm idempotent behaviour
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
  # construct inside the VM. Because the ephemeral flake the installer writes
  # uses the same `self.lib.mkHomeConfiguration` entrypoint and the same
  # nixpkgs/home-manager inputs (pinned via the registry in baseModule),
  # the store paths should match and the VM never needs to reach the network
  # to perform the switch.
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

    # Append the pre-built alice activation package so the offline run can
    # realize it without network access.
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
        "DOTFILES_URL=dotfiles "
        "DOTFILES_USER=alice "
        "DOTFILES_HOME=/home/alice "
        "DOTFILES_STATE_VERSION=25.11"
    )

    with subtest("nix run installer completes successfully"):
        succeed_as_alice(f"{installer_env} nix run dotfiles")

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
        succeed_as_alice(f"{installer_env} nix run dotfiles")
        second_gen = machine.succeed(
            "readlink /home/alice/.local/state/home-manager/gcroots/current-home"
        ).strip()
        assert first_gen == second_gen, (
            "current-home gcroot changed across idempotent runs: "
            f"{first_gen!r} -> {second_gen!r}"
        )
  '';
}
