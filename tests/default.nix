# Tests are evaluated with the nmt (Nix Module Tests) framework from
# https://git.sr.ht/~rycee/nmt.
#
# Primary entrypoint for both the flake-integrated builds (via
# legacyPackages.test-*) and stand-alone invocations:
#
#   nix-build tests/default.nix --arg home-manager '...'
#
# The returned attrset has the shape:
#   { build = { <name> = drv; all = drv; }; run = {...}; report = {...}; list = drv; }
{
  pkgs ? import <nixpkgs> { },

  # The home-manager flake input (or its outPath).  nmt requires the full Home
  # Manager module system so that options like `home.activationPackage`,
  # `xdg.configFile`, and `assertions` are defined.  The flake passes the real
  # input; stand-alone callers must supply a path to a home-manager checkout.
  home-manager,

  # The flake's self attribute, used by config-files.nix to read .config/.
  # Defaults to the repo root so stand-alone nix-build works from a checkout.
  self ? builtins.path { path = ./.. ; name = "dotfiles-src"; },

  # Minimal stub that satisfies the nix-index-database API surface used by
  # programs.nix. The flake passes the real input; the stub is good enough for
  # stand-alone test runs where comma behaviour is not under test.
  nix-index-database ? {
    homeModules.nix-index = { lib, ... }: {
      options.programs.nix-index-database.comma.enable =
        lib.mkEnableOption "comma integration with nix-index-database";
    };
  },
}:

let
  # Use Home Manager's own stdlib-extended.nix so that lib.hm (including
  # lib.hm.deprecations, lib.hm.maintainers, etc.) is fully populated — the
  # same way HM's own test suite wires lib before passing it to nmt.
  lib = import "${home-manager}/modules/lib/stdlib-extended.nix" pkgs.lib;

  nmtSrc = builtins.fetchTarball {
    url = "https://git.sr.ht/~rycee/nmt/archive/v0.5.1.tar.gz";
    sha256 = "0qhn7nnwdwzh910ss78ga2d00v42b0lspfd7ybl61mpfgz3lmdcj";
  };

  # Load the full Home Manager module set so that every HM option (including
  # `home.activationPackage`, `xdg.configFile`, `assertions`, …) is available
  # inside nmt's evalModules.
  hmModules = import "${home-manager}/modules/modules.nix" {
    inherit lib pkgs;
    check = false;
  };

  # The full dotfiles Home Manager module, wired with the same inputs the
  # flake uses.
  dotfilesModule = import ../.flake-modules/home-manager.nix {
    inherit self nix-index-database;
  };

  # Base module applied to every test. Sets the minimum option values required
  # by the dotfiles module so individual test files only declare what they
  # change.
  baseTestModule = { lib, ... }:
    let
      testUser = "test-user";
      testHome = "/home/test-user";
    in
    {
      _module.args.pkgs = lib.mkForce pkgs;
      # dotfiles.* options are required (no defaults); set them here so tests
      # that enable the module don't have to repeat them.
      dotfiles = {
        enable = lib.mkDefault false;
        username = lib.mkDefault testUser;
        homeDirectory = lib.mkDefault testHome;
      };
      # home.username/homeDirectory must always be defined; base.nix only
      # propagates from dotfiles.* when dotfiles.enable = true.
      home.username = lib.mkDefault testUser;
      home.homeDirectory = lib.mkDefault testHome;
      home.stateVersion = lib.mkDefault "25.11";
      # Suppress the manpage build; it causes unnecessary rebuilds in tests.
      manual.manpages.enable = lib.mkDefault false;
    };

  modules = hmModules ++ [ dotfilesModule baseTestModule ];

in
import nmtSrc {
  inherit lib pkgs modules;

  # nmt sets $TESTED to this attribute of the evaluated module, so assertion
  # scripts refer to paths such as home-files/.config/git/config relative to
  # the activation package.
  testedAttrPath = [ "home" "activationPackage" ];

  tests = import ./modules;
}
