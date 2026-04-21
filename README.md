# dotfiles

Personal home-manager environment, managed as a Nix flake.

## What's included

| Program | Config location |
|---|---|
| Fish shell | `.config/fish/` |
| Neovim | `.config/nvim/` |
| Kitty | `.config/kitty/` |
| oh-my-posh | `.config/oh-my-posh/` |
| Git | `.config/git/` |
| direnv + nix-direnv | managed by `programs.direnv` |
| nix-index + comma | managed by `programs.nix-index-database` |

Packages installed: `kitty`, `nix-your-shell`, `oh-my-posh`.

---

## Standalone usage

Apply the bundled home configuration directly (useful on a fresh machine):

```bash
git add -A                              # home-manager reads from git — stage everything first
nix flake check                         # validate before applying
home-manager switch --flake .#ferndq   # activate
```

`home.username`, `home.homeDirectory`, and `home.stateVersion` are hard-coded in
the standalone configuration (`homeConfigurations.ferndq`). For other machines,
consume the module instead (see below).

---

## Adding this module to another flake

The flake exposes a reusable home-manager module at `homeManagerModules.default`.
It is designed to be imported into a NixOS (or standalone home-manager) flake and
configured with the `dotfiles.*` options.

### 1 — Add the inputs

```nix
# flake.nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  dotfiles = {
    url = "github:TheFurnace/dotfiles";   # adjust to your actual remote
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

> **Note:** `nix-index-database` is a dependency of this module but is declared
> as an input *inside* this flake, so the consuming flake does **not** need to
> add it separately — it is resolved transitively.

### 2a — NixOS (via `home-manager` NixOS module)

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:TheFurnace/dotfiles";   # adjust to your actual remote
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.alice = {
            imports = [ dotfiles.homeManagerModules.default ];

            # Required — these are not set by the module itself
            dotfiles.username      = "alice";
            dotfiles.homeDirectory = "/home/alice";
            home.stateVersion      = "25.11";

            # Optional dotfiles options (see below)
            dotfiles.mutable   = false;
          };
        }
      ];
    };
  };
}
```

### 2b — Standalone home-manager flake

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:TheFurnace/dotfiles";   # adjust to your actual remote
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, ... }:
  let
    system = "x86_64-linux";
    pkgs   = nixpkgs.legacyPackages.${system};
  in {
    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        dotfiles.homeManagerModules.default
        {
          dotfiles.username      = "alice";
          dotfiles.homeDirectory = "/home/alice";
          home.stateVersion      = "25.11";
        }
      ];
    };
  };
}
```

Then apply with:

```bash
home-manager switch --flake .#alice
```

---

## Module options

| Option | Type | Default | Description |
|---|---|---|---|
| `dotfiles.username` | `str` | — | The home-manager user. Sets `home.username`. **Required.** |
| `dotfiles.homeDirectory` | `str` | — | Absolute path to the user's home directory. Sets `home.homeDirectory`. **Required.** |
| `dotfiles.mutable` | `bool` | `false` | When `true`, config files are live symlinks into `localPath` instead of Nix store copies. Edits to existing files take effect immediately (e.g. after `exec fish`). Adding or removing files still requires a rebuild. |
| `dotfiles.localPath` | `str` | `""` | Absolute path to the local checkout of this repo. Required (and only used) when `mutable = true`. |

### Mutable mode example

```nix
dotfiles.mutable   = true;
dotfiles.localPath = "/home/alice/repos/dotfiles";
```

With this configuration, every file under `.config/` in the local checkout is
symlinked directly into `~/.config/`. Changes saved to disk take effect in the
next shell session without a rebuild. A rebuild is still needed when files are
added or removed (so home-manager can create or delete the corresponding symlinks).

---

## Keeping the consuming flake up to date

This flake's `flake.lock` pins a specific git revision. To pull in new commits:

```bash
# inside the consuming repo
nix flake update dotfiles
# then rebuild — e.g. nixos-rebuild switch or home-manager switch
```

Commit the updated `flake.lock` separately from any functional changes.

---

## Cautions

- **Do not enable `programs.fish`** in the consuming config. This module owns
  `fish/config.fish` directly via `xdg.configFile`; enabling the home-manager
  fish module alongside it will cause a conflict. Shell hooks (direnv, etc.) are
  wired through `fish/conf.d/` files instead.
- `nix-index-database` is used in place of running `nix-index` locally (which
  gets OOM-killed on most machines). The `comma` integration is enabled
  automatically via `programs.nix-index-database.comma.enable`.
- Files in `.config/` are discovered at evaluation time with `builtins.readDir`.
  New subdirectories are picked up automatically on the next rebuild — no manual
  wiring in `flake.nix` is needed.
