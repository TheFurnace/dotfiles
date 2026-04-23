# Dotfiles — Agent Context

## Project purpose

Home-manager environment, managed as a flake.
Consumed by the NixOS config (`~/nixos`) as a flake input, and usable standalone on any machine.

## Design goals

- **Single source of truth for the user environment** — packages, program config, and config files all live here. The NixOS repo does not duplicate anything owned by this repo.
- **Two usage modes** — `mutable` (live symlinks into the local checkout for fast iteration) and `immutable` (Nix store copies, default). The mode is set by the `dotfiles.mutable` option in the consuming config.
- **Config files as first-class flake outputs** — `.config/` is the canonical location for all config file content. `flake.nix` walks it recursively at evaluation time and maps everything into `xdg.configFile`.
- **`programs.fish` is intentionally not enabled** — the module owns `fish/config.fish` directly via `xdg.configFile`. Enabling `programs.fish` would conflict. Shell hooks are wired via `conf.d/` files instead.

## Layout

```
flake.nix            # inputs, homeConfigurations, homeManagerModules
.config/             # config file content (fish, nvim, kitty, oh-my-posh, git, …)
setup.sh             # bootstrap script for first-time setup on a new machine
```

## What lives where

| Concern | Location |
|---|---|
| Package list | `flake.nix` — `home.packages` |
| Program options (neovim, direnv, …) | `flake.nix` — `programs.*` |
| Config file content | `.config/<program>/` |
| Shell hooks (direnv, nix-your-shell, …) | `.config/fish/conf.d/` |
| Machine identity (`username`, `homeDirectory`, `stateVersion`) | Consuming system config |
| Machine-specific or experimental config | Consuming system config |

## Workflow

### Standalone (this repo directly)

1. **Stage changes** — home-manager evaluates the flake from git and silently ignores untracked or unstaged files. Always stage first:
   ```
   git add -A
   ```
2. **Validate** before applying:
   ```
   nix flake check
   ```
3. **Apply** to the running user environment:
   ```
   home-manager switch --flake .#example
   ```
4. **Commit** once the result is confirmed working. Keep commits atomic and scoped to one logical change.
5. **Update inputs** intentionally, not as a side effect of other changes:
   ```
   nix flake update
   ```
   Treat `flake.lock` changes as their own commit.

### When consumed as a flake input

Changes pushed here are not picked up by a consuming flake automatically — its `flake.lock` pins a specific revision. To pull in new changes, in the consuming repo:

1. Push commits to the remote.
2. Update the input and rebuild:
   ```
   nix flake update dotfiles
   # then rebuild however that system applies its config
   ```
3. Commit the updated `flake.lock` in the consuming repo separately.

### Mutable mode (live editing)

When `dotfiles.mutable = true` and `dotfiles.localPath` points to this checkout, `xdg.configFile` entries are live symlinks instead of store copies. This means:

- **Edits to existing files** take effect immediately (e.g. after `exec fish`) — no rebuild needed.
- **Adding or removing files** still requires a rebuild so the symlink set can be updated.

## Cautions

- Do not enable `programs.fish` — the module owns `fish/config.fish` directly via `xdg.configFile` and the two will conflict.
- `flake.nix` walks `.config/` at evaluation time using `builtins.readDir`. New subdirectories are picked up automatically on the next rebuild; no manual wiring is needed.
- `nix-index-database` is used instead of running `nix-index` locally (which gets OOM-killed). The `comma` integration is enabled via `programs.nix-index-database.comma.enable`.

Commit guidance

- When changing Nix or Home Manager config: run `nix flake check` to validate, then commit with a short, descriptive message.

