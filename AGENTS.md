# Dotfiles — Agent Context

## Project purpose

Home-manager environment, managed as a flake.
Consumed by the NixOS config (`~/nixos`) as a flake input, and usable standalone on any machine.

## Design goals

- **Single source of truth for the user environment** — packages, program config, and config files all live here. The NixOS repo does not duplicate anything owned by this repo.
- **Two usage modes** — `mutable` (live symlinks into the local checkout for fast iteration) and `immutable` (Nix store copies, default). The mode is set by the `dotfiles.mutable` option in the consuming config.
- **Config files as first-class flake outputs** — `.config/` is the canonical location for all non-fish config file content. `flake.nix` walks it recursively at evaluation time and maps everything into `xdg.configFile`.
- **`programs.fish` is enabled** — fish shell init, functions, and tool hooks (direnv, zoxide, nix-your-shell, oh-my-posh) are all declared via `programs.fish` in Nix. The `.config/fish/` directory is not used.

## Layout

```
flake.nix                   # inputs, exported modules, lib helpers, test wiring
flake.lock                  # locked input versions
.config/                    # config file content (nvim, kitty, oh-my-posh, git, …)
.flake-modules/             # implementation modules (home-manager, nixos, installer, lib, dev-shell)
tests/
  default.nix               # nmt test suite entrypoint
  modules/                  # nmt unit tests (one .nix file per test case)
  integration/              # NixOS VM integration tests
  tests.py                  # Python test runner (nix run .#packages.x86_64-linux.tests)
  package.nix               # wraps tests.py as a runnable Nix package
```

## What lives where

| Concern | Location |
|---|---|
| Package list | `.flake-modules/home-manager/packages.nix` — `home.packages` |
| Program options (neovim, direnv, fish, …) | Home Manager modules under `.flake-modules/home-manager/` — `programs.*` |
| Config file content (non-fish) | `.config/<program>/` |
| Fish shell init, functions, hooks | Home Manager modules — primarily `.flake-modules/home-manager/fish/*.nix`, with tool-specific fish integrations also declared in related modules such as `.flake-modules/home-manager/programs.nix` |
| Public helpers for downstream flakes | `.flake-modules/lib.nix` — `lib.mkHomeConfiguration`, `lib.mkNixosConfiguration` |
| Installer (`nix run` bootstrap) | `.flake-modules/installer.nix` |
| nmt unit tests | `tests/modules/` |
| NixOS VM integration tests | `tests/integration/` |
| Machine identity (`username`, `homeDirectory`, `stateVersion`) | Consuming system config |
| Machine-specific or experimental config | Consuming system config |

## Installer

First-time setup on a new machine is done via:

```sh
# Write $XDG_CONFIG_HOME/home-manager/flake.nix only (no activation).
nix run github:TheFurnace/dotfiles -- init

# Write the flake and immediately activate with home-manager switch.
nix run github:TheFurnace/dotfiles -- init --switch
```

The installer writes a small consumer flake to `~/.config/home-manager/flake.nix` using
`dotfiles.lib.mkHomeConfiguration`. It is idempotent — re-running it when the file already
exists is a no-op.

## Tests

### Test kinds

| Kind | Location | Framework | Use it when |
|---|---|---|---|
| nmt unit tests | `tests/modules/` | [nmt](https://git.sr.ht/~rycee/nmt) | **Default validation** for Home Manager modules, generated configuration, package declarations, and config-file linking. Fast; does not boot a VM. |
| NixOS VM integration tests | `tests/integration/` | NixOS `makeTest` | The behavior can only be validated from a fresh NixOS VM, such as installer/init behavior or a new full end-to-end bootstrap flow. Slow; boots a VM. |

### How to run tests

```sh
# Run all nmt unit tests (the standard validation command; fast, no VM):
nix run .#packages.x86_64-linux.tests

# Run a subset by name substring while iterating:
nix run .#packages.x86_64-linux.tests -- config

# List available tests:
nix run .#packages.x86_64-linux.tests -- -l

# Run the installer VM integration test (slow; only when a fresh VM is needed):
nix build .#checks.x86_64-linux.installer-bootstrap
```

`python3 tests/tests.py` accepts the same arguments when Python is already available on
`PATH`; use the `nix run` form above for a self-contained command.

### Selecting validation

- Run the full **nmt unit suite** for nearly every code or configuration change. Use its
  targeted form while iterating, then run the full suite before committing.
- Run `nix build .#checks.x86_64-linux.installer-bootstrap` or `nix flake check` **only**
  when the change needs a fresh NixOS VM to validate: installer `init` / `init --switch`
  behavior, first-run or idempotency behavior, VM test infrastructure, or a genuinely new
  end-to-end system flow.
- Do not run a VM test solely because a change is written in Nix. Home Manager options,
  packages, generated activation content, and `.config/` links should normally be covered
  by nmt tests.

### When to add tests

Add a new **nmt unit test** (`tests/modules/`) whenever you:
- Add or change a Home Manager option in `.flake-modules/home-manager/`
- Add a new config file under `.config/` that should be linked into the activation package
- Fix a bug that was caused by incorrect module composition

Add a new **integration test** (`tests/integration/`) whenever you:
- Change the installer behaviour (`init`, `init --switch`, idempotency)
- Add a new end-to-end flow that requires a real NixOS system to validate

### How to add an nmt unit test

1. Create `tests/modules/<descriptive-name>.nix`. The module receives the same base
   configuration as every other test (see `tests/default.nix`), so only declare what you
   are testing:
   ```nix
   {
     dotfiles.enable = true;
     # … set any option under test …

     nmt.script = ''
       assertFileExists home-files/.config/git/config
       # nmt assertion helpers: assertFileExists, assertFileContent, assertPathNotExists, …
     '';
   }
   ```
2. Register the test in `tests/modules/default.nix` by adding an attribute whose value is
   the path to your new file.
3. Run `python3 tests/tests.py <name>` to verify it passes.

## Workflow

- create a plan and present it to the user
- make changes as needed
- run `nix run .#packages.x86_64-linux.tests` to verify the standard nmt validation
- run the targeted VM integration test (or `nix flake check`) only when the change requires
  fresh-VM, end-to-end validation as described above
- commit changes

### `nix flake check` failures in cloud/CI environments

`nix flake check` runs the NixOS VM integration tests. These VMs run on the
NixOS test framework's isolated VDE network, not the host's normal network, so
an integration test must not depend on outbound DNS or Internet access. A host
may successfully reach `cache.nixos.org` while the test VM cannot resolve it.

**Keep VM tests hermetic.** Pre-build and add every store closure the in-VM
command can need to `system.extraDependencies`; do not rely on a VM download
from `cache.nixos.org`, GNU mirrors, `www.python.org`, or other upstream hosts.
A `Could not resolve host` error from a VM means a needed dependency was not
seeded into the VM, not necessarily that the host network or cache is down.

**Run targeted, offline-capable validation first.** When a change requires `nix flake check`,
always run `nix run .#packages.x86_64-linux.tests` first (nmt unit tests — no network, no
VM). If those pass, proceed to `nix flake check` and inspect any failure carefully.

When an integration test reports an external fetch attempt:
1. Quote the **exact** error line(s) and identify the missing dependency or host.
2. Check whether the host itself can resolve the host before calling it an external outage.
3. Add the required closure to the VM's seeded dependencies, then re-run the check.
4. Do **not** claim the code is definitively correct until the hermetic VM test passes.

**Do not weaken TLS verification or change Nix security settings** (e.g. setting
`nix.settings.accept-flake-config`, disabling certificate checks, or adding untrusted
substituters) to work around a missing VM closure. These would introduce security
regressions.

**If the logs do not show network/TLS/download indicators,** treat the failure as a real
code or test issue and investigate it normally.

## Cautions

- `flake.nix` walks `.config/` at evaluation time using `builtins.readDir`. New subdirectories are picked up automatically on the next rebuild; no manual wiring is needed.
- `nix-index-database` is used instead of running `nix-index` locally (which gets OOM-killed). The `comma` integration is enabled via `programs.nix-index-database.comma.enable`.

## Commits guidance

- Before committing, run the full nmt suite for code or configuration changes. Run
  `nix flake check` only when the change meets the fresh-VM criteria in **Selecting validation**.
- After any stopping point, commit with a descriptive message.
