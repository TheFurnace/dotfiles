# Dotfiles agent context

## Purpose

This flake is a reusable preferred Linux user environment. It supports NixOS,
standalone Home Manager, and generic Linux/WSL on `x86_64-linux` and
`aarch64-linux`.

Read `docs/architecture.md` before changing module boundaries. The important
split is:

- Nix owns reproducible packages, configuration, and helper scripts.
- Pi and Codex remain mutable upstream-managed tools behind the explicit
  `dotfiles-ai` interface.
- Consumers own user identity, secrets, and host-specific configuration.

Home Manager activation must stay deterministic and offline-capable. Never add
`curl | sh`, package-manager updates, or other network mutations to activation.

## Layout

```text
flake.nix                    Public outputs and per-system composition
.flake-modules/
  home-manager/              Reusable user environment
  nixos/                     NixOS + Home Manager integration
  installer.nix              nix run bootstrap app
  lib.nix                    Public configuration constructors
  lib/setup-shell.nix        Shared login-shell implementation
.config/                     Recursively managed XDG configuration assets
tests/modules/               Fast nmt module tests
tests/integration/           Fresh NixOS VM bootstrap tests
.github/workflows/ci.yml     Fast PR/main validation
.github/workflows/installer.yml
                             Path-scoped bootstrap VM validation
.github/workflows/flake-update.yml
                             Scheduled lock update and full validation
```

## Module conventions

- Keep `flake.nix` as composition glue; implementation belongs in
  `.flake-modules/`.
- Gate every Home Manager contribution with `dotfiles.enable`.
- Put stable packages in `home-manager/packages.nix` or a focused feature
  module. Do not package fast-moving Pi/Codex binaries in Nix.
- Add non-Fish configuration below `.config/`; `config-files.nix` discovers it
  recursively. Express Fish configuration through `programs.fish`.
- Honor resolved Home Manager paths such as `config.xdg.configHome`; do not
  hard-code `~/.config`.
- Keep machine identity and secrets out of this repository.
- Keep Linux system lists centralized in `flake.nix` and installer output
  generation. Do not advertise an untested platform.

## Validation

The standard validation command is:

```sh
nix run .#packages.x86_64-linux.tests
```

Use a substring while iterating:

```sh
nix run .#packages.x86_64-linux.tests -- ai
nix run .#packages.x86_64-linux.tests -- -l
```

Add or update an nmt case when changing Home Manager options, package groups,
generated shell content, or managed files. Register new cases in
`tests/modules/default.nix`.

Run the VM test only when changing installer commands, generated consumer
flakes, login-shell setup, or fresh-machine behavior:

```sh
nix build .#checks.x86_64-linux.installer-bootstrap
```

The integration VM has no dependable outbound Internet. Seed every required
store closure through `system.extraDependencies`; never weaken TLS or Nix
security to make a VM test pass.

For cross-platform output changes, evaluate both supported systems:

```sh
nix eval .#packages.x86_64-linux --apply builtins.attrNames
nix eval .#packages.aarch64-linux --apply builtins.attrNames
nix eval .#apps.x86_64-linux --apply builtins.attrNames
nix eval .#apps.aarch64-linux --apply builtins.attrNames
```

## Workflow

1. Present a plan for non-trivial changes.
2. Keep the reusable core and mutable edge boundary explicit.
3. Add focused tests while implementing.
4. Run the complete nmt suite.
5. Run the installer VM test only when its contract changed.
6. Review the final diff and commit descriptive, coherent changes.
