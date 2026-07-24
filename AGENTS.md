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

| Kind | Location | Framework | When it runs |
|---|---|---|---|
| nmt unit tests | `tests/modules/` | [nmt](https://git.sr.ht/~rycee/nmt) | `python3 tests/tests.py` / `nix run .#packages.x86_64-linux.tests` / CI |
| NixOS VM integration tests | `tests/integration/` | NixOS `makeTest` | `nix build .#checks.x86_64-linux.<name>` / `nix flake check` / CI |

### How to run tests

```sh
# Run all nmt unit tests (fast, no VM):
python3 tests/tests.py

# Run a subset by name substring:
python3 tests/tests.py config

# List available tests:
python3 tests/tests.py -l

# Run integration tests (boots a VM — slow):
nix build .#checks.x86_64-linux.installer-bootstrap
```

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
- run `python3 tests/tests.py` to verify nmt unit tests pass
- validate changes with `nix flake check`
- commit changes

### `nix flake check` failures in cloud/CI environments

`nix flake check` runs the NixOS VM integration tests, which boot a real VM and download
external dependencies. In cloud agent environments these can fail for reasons unrelated to
your code changes.

**Run targeted, offline-capable validation first.** Before running `nix flake check`, always
run `python3 tests/tests.py` (nmt unit tests — no network, no VM). If those pass, proceed
to `nix flake check` and inspect any failure carefully.

**When a `nix flake check` failure is infrastructure/external only:** Treat it as such
*only* when the logs specifically show one or more of these indicators:
- TLS certificate-chain errors (e.g. "self-signed certificate in certificate chain") when
  fetching from `cache.nixos.org` or other substituters
- Substituter or binary cache access failures (403, connection refused, DNS failure)
- Repeated download timeouts from external hosts (GNU mirrors, `www.python.org`, etc.)

When you identify an infrastructure failure:
1. Quote the **exact** error line(s) from the log.
2. Name the **exact** external dependency or host that failed.
3. State clearly which targeted tests passed and which check was blocked by the infra issue.
4. Do **not** claim the code is definitively correct — a real code issue could coexist with a
   transient network failure.

**Do not weaken TLS verification or change Nix security settings** (e.g. setting
`nix.settings.accept-flake-config`, disabling certificate checks, or adding untrusted
substituters) to work around infrastructure failures. These would introduce security
regressions.

**If the logs do not show network/TLS/download indicators,** treat the failure as a real
code or test issue and investigate it normally.

## Cautions

- `flake.nix` walks `.config/` at evaluation time using `builtins.readDir`. New subdirectories are picked up automatically on the next rebuild; no manual wiring is needed.
- `nix-index-database` is used instead of running `nix-index` locally (which gets OOM-killed). The `comma` integration is enabled via `programs.nix-index-database.comma.enable`.

## Commits guidance

- When changing Nix or Home Manager config: run `nix flake check` to validate before committing.
- After any stopping point, commit with a descriptive message.
