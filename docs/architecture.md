# Architecture

## Goal

Provide one preferred user environment that can be consumed from multiple
Linux systems without making a particular host, checkout path, or package
manager layout part of the reusable core.

## Boundaries

### Nix owns stable state

The flake owns packages, program options, generated configuration, XDG files,
shell integration, and the small scripts needed to operate the environment.
Home Manager activation must be deterministic and must not require Internet
access.

### Upstream owns fast-moving AI clients

Pi and Codex are intentionally not pinned in the Nix closure. Their official
install/update mechanisms own the executable and bundled runtimes. Nix owns
their stable supporting tools and exposes a single explicit `dotfiles-ai`
interface.

This is a conscious reproducibility trade-off: rebuilding the environment is
repeatable, while updating an agent is an explicit mutable operation.

### Generic consumers own identity and machines

Usernames, home directories, state versions, secrets, Git author identity,
host hardware, and host-specific NixOS settings stay in consuming flakes when
the repository is used as a library.

A direct clone is also a consumer. Its non-secret identity defaults live in
`defaults.nix`, which feeds only `homeConfigurations.default` and
`nixosConfigurations.default`. Machine hardware and boot decisions remain
explicit modules referenced from that file; the reusable module layer never
guesses them.

## Composition

```text
flake.nix
├── homeManagerModules.default
│   ├── core shell/editor/git configuration
│   ├── recursively managed .config assets
│   ├── optional desktop and development packages
│   └── optional AI dependencies + dotfiles-ai manager
├── nixosModules.default
│   ├── Home Manager integration
│   └── Fish login-shell integration
├── lib.mkHomeConfiguration
├── lib.mkNixosConfiguration
├── defaults.nix
│   ├── homeConfigurations.default
│   └── nixosConfigurations.default
└── installer app
    ├── interactively reviews consumer identity and optional mutable tools
    ├── writes and activates a small consumer flake
    └── supports an explicit unattended path for automation
```

## Invariants

1. Enabling the module does not access the network during activation.
2. Disabling the module contributes no managed files or packages.
3. Optional feature groups can be disabled independently.
4. Immutable mode never depends on a local checkout.
5. Mutable mode requires an explicit absolute checkout path.
6. Configuration honors Home Manager's resolved XDG paths.
7. The bootstrap-generated flake records the platform of the installer app.
8. Fast module tests cover generated state; the host-side integration runner
   covers fresh-user bootstrap behavior with an empty home and closure-only
   executable environment.

## Supported platforms

The flake publishes packages, apps, tests, and development shells for
`x86_64-linux` and `aarch64-linux`. The installer integration runner is
currently published for `x86_64-linux`, matching the CI host used to exercise
the generic-Linux bootstrap path.

Darwin is intentionally not advertised. Supporting it later should begin with
an explicit platform contract and CI coverage rather than accidental
evaluation success.
