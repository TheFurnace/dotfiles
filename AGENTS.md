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

- create a plan and present it to the user
- make changes as needed
- validate changes with `nix flake check`
- commit changes

## Cautions

- Do not enable `programs.fish` — the module owns `fish/config.fish` directly via `xdg.configFile` and the two will conflict.
- `flake.nix` walks `.config/` at evaluation time using `builtins.readDir`. New subdirectories are picked up automatically on the next rebuild; no manual wiring is needed.
- `nix-index-database` is used instead of running `nix-index` locally (which gets OOM-killed). The `comma` integration is enabled via `programs.nix-index-database.comma.enable`.

## Commits guidance

- When changing Nix or Home Manager config: run `nix flake check` to validate before committing.
- After any stopping point, commit with a descriptive message.

