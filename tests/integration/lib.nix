# Reusable harness for NixOS VM integration tests in this repo.
#
# Centralizes the bits that every end-to-end test of the dotfiles installer
# tends to need so individual test files can stay focused on the scenario
# they exercise:
#
#   * `makeTest` — `nixosLib.runTest` with `hostPkgs` already wired up.
#   * `baseModule` — a NixOS module that points the `dotfiles`/`nixpkgs`/
#     `home-manager` flake registry entries at local store paths, enables
#     flakes, disables network substituters, pre-seeds the store with the
#     dotfiles + HM CLI closures, and gives the VM enough RAM/disk to run
#     Home Manager activation offline.
#   * `aliceModule` — a normal user `alice` (uid 1000, /home/alice) with
#     autologin on tty1, so user-scoped commands like `nix run dotfiles`
#     have a real session to run in.
#   * `system` — the host system string, re-exported so callers don't have
#     to recompute `pkgs.stdenv.hostPlatform.system`.
#
# Adding a new VM test typically looks like:
#
#   let
#     helpers = import ./lib.nix { inherit pkgs self home-manager nixpkgs; };
#   in
#   helpers.makeTest {
#     name = "...";
#     nodes.machine = { ... }: {
#       imports = [ helpers.baseModule helpers.aliceModule ];
#       # ...test-specific overrides...
#     };
#     testScript = "...";
#   }
{ pkgs, self, home-manager, nixpkgs }:

let
  inherit (pkgs) lib;

  system = pkgs.stdenv.hostPlatform.system;

  nixosLib = import "${nixpkgs}/nixos/lib" { };

  baseModule = { lib, ... }: {
    imports = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    ];

    virtualisation = {
      # Home Manager activation evaluates a fair amount of Nix; give the VM
      # enough headroom to avoid OOM during `home-manager switch`.
      memorySize = lib.mkDefault 4096;
      diskSize = lib.mkDefault 8192;
      cores = lib.mkDefault 2;
    };

    nix = {
      # Resolve the flake refs used by the installer to local store paths so
      # the test can run without network access. `dotfiles` is the alias the
      # installer's ephemeral flake references (via DOTFILES_URL=dotfiles).
      registry = {
        dotfiles.to = {
          type = "path";
          path = "${self}";
        };
        nixpkgs.to = lib.mkForce {
          type = "path";
          path = "${nixpkgs}";
        };
        home-manager.to = {
          type = "path";
          path = "${home-manager}";
        };
      };

      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        # Deny network substituters; integration tests must be self-contained.
        substituters = lib.mkForce [ ];
        trusted-substituters = lib.mkForce [ ];
      };
    };

    # Pre-seed the store with everything the installer's ephemeral flake will
    # need at evaluation time. Individual tests can append test-specific
    # closures (e.g. a pre-built activation package) via the standard list
    # merge on `system.extraDependencies`.
    system.extraDependencies = [
      self
      nixpkgs.outPath
      home-manager.outPath
      home-manager.packages.${system}.home-manager
    ];
  };

  aliceModule = { ... }: {
    users.users.alice = {
      isNormalUser = true;
      description = "Alice";
      password = "foobar";
      uid = 1000;
      home = "/home/alice";
    };

    # Autologin alice on tty1 so a real user session (with XDG_RUNTIME_DIR
    # and a user systemd instance) is available for Home Manager activation.
    services.getty.autologinUser = "alice";
  };

  makeTest = args: nixosLib.runTest ({
    hostPkgs = pkgs;
  } // args);
in
{
  inherit makeTest baseModule aliceModule system lib;
}
