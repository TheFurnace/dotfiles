# dotfiles

Plug-and-play dotfiles for Home Manager and NixOS.

## Table of contents

- [What the module configures](#what-the-module-configures)
- [NixOS: full plug-and-play setup](#nixos-full-plug-and-play-setup)
  - [Example](#example)
  - [Mutable mode on NixOS](#mutable-mode-on-nixos)
- [Non-NixOS or standalone Home Manager](#non-nixos-or-standalone-home-manager)
  - [Quick install](#quick-install)
  - [Example](#example-1)
  - [One-time login shell step on non-NixOS](#one-time-login-shell-step-on-non-nixos)
- [Standalone configs bundled in this repo](#standalone-configs-bundled-in-this-repo)
- [NixOS helper options: `lib.mkNixosConfiguration`](#nixos-helper-options-libmknixosconfiguration)
- [Module options](#module-options)
  - [Home Manager module: `homeManagerModules.default`](#home-manager-module-homemanagermodulesdefault)
  - [NixOS module: `nixosModules.default`](#nixos-module-nixosmodulesdefault)
- [Updating this flake when used as an input](#updating-this-flake-when-used-as-an-input)
- [Testing](#testing)
- [Development shell](#development-shell)
- [Notes](#notes)

This flake now exposes four useful entry points:

- `homeManagerModules.default` — use this in standalone Home Manager or on non-NixOS systems
- `nixosModules.default` — use this on NixOS for the full plug-and-play setup, including fish as the user's login shell
- `lib.mkHomeConfiguration` — helper for creating a standalone Home Manager configuration without copying boilerplate
- `lib.mkNixosConfiguration` — helper for creating a NixOS configuration with the dotfiles module and a fish login shell already wired

## What the module configures

The module installs or enables everything needed for the environment in this repo:

- `fish`
- `oh-my-posh`
- `git`
- `kitty`
- `neovim`
- `direnv` + `nix-direnv`
- `nix-index-database` + `comma`
- `nix-your-shell`
- `fira-code` plus user fontconfig so the kitty font setting works

Git aliases and editor settings are included, but `git user.name` and `git user.email` are intentionally left unset so the flake stays generic.

Config files are sourced directly from `.config/`:

| Program | Source directory |
|---|---|
| Git | `.config/git/` |
| Kitty | `.config/kitty/` |
| Neovim | `.config/nvim/` |
| oh-my-posh | `.config/oh-my-posh/` |

Fish shell is configured via `programs.fish` (Home Manager's built-in module), so its shell init, functions, and tool hooks are all declared in Nix rather than stored under `.config/fish/`. The oh-my-posh prompt and nix-your-shell hook are wired automatically through `programs.fish.interactiveShellInit`.

---

## NixOS: full plug-and-play setup

On NixOS, use `dotfiles.nixosModules.default`.

This module:

- imports Home Manager for you
- installs all required packages
- configures all files under `.config/`
- enables fish system-wide
- sets the target user's shell to fish
- wires oh-my-posh automatically

### Example

You can wire the NixOS module manually:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    dotfiles = {
      url = "github:TheFurnace/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, dotfiles, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        dotfiles.nixosModules.default
        {
          users.users.ferndq = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
          };

          dotfiles = {
            enable = true;
            username = "ferndq";
            stateVersion = "25.11";
          };
        }
      ];
    };
  };
}
```

Or use the helper this flake exports:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    dotfiles = {
      url = "github:TheFurnace/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { dotfiles, ... }: {
    nixosConfigurations.my-machine = dotfiles.lib.mkNixosConfiguration {
      hostname = "my-machine";
      username = "ferndq";
      stateVersion = "25.11";
      extraModules = [ ./configuration.nix ];
    };
  };
}
```

There is also a built-in `nixosConfigurations.example` output in this flake as a minimal reference configuration.

Then apply normally:

```bash
sudo nixos-rebuild switch --flake .#my-machine
```

### Mutable mode on NixOS

For live editing from a local checkout:

```nix
dotfiles = {
  enable = true;
  username = "ferndq";
  stateVersion = "25.11";

  mutable = true;
  localPath = "/home/ferndq/repos/dotfiles";
};
```

In mutable mode, edits to existing files under `.config/` take effect immediately. Adding or removing files still requires a rebuild.

If your NixOS user has a nonstandard home directory, also set `dotfiles.homeDirectory` to match it.

---

## Non-NixOS or standalone Home Manager

### Quick install

Run the installer directly from this flake — no local clone required:

```bash
nix run github:TheFurnace/dotfiles -- init
```

This writes `$XDG_CONFIG_HOME/home-manager/flake.nix` (typically
`~/.config/home-manager/flake.nix`) wired to pull in this flake's Home Manager
module.  It mirrors the `home-manager init` pattern so you can inspect or
customise the generated flake before activating.

If a `flake.nix` already exists at that path, `init` skips writing and leaves
the existing file untouched.  Delete it first if you want to regenerate from
scratch.

Once you are happy with the flake, activate with:

```bash
home-manager switch -b backup --flake ~/.config/home-manager#<your-username>
```

Or, to write the flake **and** immediately activate the environment in one step
(skips writing if the file already exists):

```bash
nix run github:TheFurnace/dotfiles -- init --switch
```

The installer detects your username and home directory automatically.

#### Environment overrides

| Variable | Default | Purpose |
|---|---|---|
| `DOTFILES_USER` | `$USER` / `id -un` | Unix username for the Home Manager profile |
| `DOTFILES_HOME` | `$HOME` | Absolute path to your home directory |
| `DOTFILES_STATE_VERSION` | `25.11` | Home Manager state version |
| `DOTFILES_URL` | `github:TheFurnace/dotfiles` | Dotfiles flake URL (useful for testing a local checkout: `DOTFILES_URL=/path/to/checkout nix run .#default`) |
| `DOTFILES_NIXPKGS_URL` | _(unset)_ | Optional nixpkgs override for the installer flake. When unset, the generated flake follows `dotfiles/nixpkgs` from the dotfiles lock file. |
| `DOTFILES_HOME_MANAGER_URL` | _(unset)_ | Optional home-manager override for the installer flake. When unset, the generated flake follows `dotfiles/home-manager` from the dotfiles lock file. |

On non-NixOS, use `dotfiles.homeManagerModules.default`.

This installs the same user environment, enables `programs.home-manager`, and wires fish + oh-my-posh automatically, but there is one platform limitation to be aware of:

- Home Manager can install and configure fish
- Home Manager cannot reliably change the system login shell on non-NixOS by itself

So the setup is almost entirely plug-and-play, but changing the OS-level login shell is still a one-time system step outside Home Manager.

### Example

You can still wire the module manually:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:TheFurnace/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations.ferndq = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          dotfiles.homeManagerModules.default
          {
            dotfiles = {
              enable = true;
              username = "ferndq";
              homeDirectory = "/home/ferndq";
            };

            home.stateVersion = "25.11";
          }
        ];
      };
    };
}
```

Or, more simply, use the helper this flake exports:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:TheFurnace/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, dotfiles, ... }: {
    homeConfigurations.ferndq = dotfiles.lib.mkHomeConfiguration {
      username = "ferndq";
      homeDirectory = "/home/ferndq";
      stateVersion = "25.11";
    };
  };
}
```

Apply it with:

```bash
git add -A
home-manager switch -b backup --flake .#ferndq
```

When fish is your login shell in standalone Home Manager mode, `programs.fish` ensures the Home Manager profile is on `PATH` automatically.

### One-time login shell step on non-NixOS

After the first activation, fish and oh-my-posh are installed and ready. If you also want your OS login shell to be fish, run:

```bash
chsh -s "$(command -v fish)"
```

Depending on the distro, the fish path may need to exist in `/etc/shells` first.

---

## Standalone configs bundled in this repo

This flake exposes a generic standalone example configuration at `.#example`:

```bash
git add -A
nix flake check
home-manager switch -b backup --flake .#example
```

Treat that built-in output as an example. For real usage, standalone consumption is better done with `dotfiles.lib.mkHomeConfiguration`, which lets another flake create a Home Manager configuration with just:

```nix
dotfiles.lib.mkHomeConfiguration {
  username = "ferndq";
  homeDirectory = "/home/ferndq";
  stateVersion = "25.11";
}
```

The helper also supports:

- `system`
- `mutable`
- `localPath`
- `extraModules`
- `extraSpecialArgs`

## NixOS helper options: `lib.mkNixosConfiguration`

`mkNixosConfiguration` accepts:

- `hostname`
- `username`
- `homeDirectory` (optional; defaults to `/home/${username}`. If your NixOS user has a different home path, set this explicitly.)
- `stateVersion` for Home Manager
- `nixosStateVersion` (defaults to `stateVersion`)
- `system`
- `mutable`
- `localPath`
- `user` for extra `users.users.<name>` fields
- `extraModules`
- `extraSpecialArgs`

---

## Module options

### Home Manager module: `homeManagerModules.default`

| Option | Type | Default | Description |
|---|---|---|---|
| `dotfiles.enable` | `bool` | `false` | Enable the module. |
| `dotfiles.username` | `str` | — | Sets `home.username`. |
| `dotfiles.homeDirectory` | `str` | — | Sets `home.homeDirectory`. |
| `dotfiles.mutable` | `bool` | `false` | Use live symlinks into a local checkout instead of store copies. |
| `dotfiles.localPath` | `str` | `""` | Required when `dotfiles.mutable = true`. |

### NixOS module: `nixosModules.default`

| Option | Type | Default | Description |
|---|---|---|---|
| `dotfiles.enable` | `bool` | `false` | Enable the NixOS integration. |
| `dotfiles.username` | `str` | — | User whose Home Manager profile should receive the dotfiles. |
| `dotfiles.homeDirectory` | `null or str` | `null` | Optional home directory override. Defaults to `/home/<name>`. If your NixOS user uses a different home path, set this explicitly. |
| `dotfiles.stateVersion` | `str` | — | Home Manager state version for that user. |
| `dotfiles.mutable` | `bool` | `false` | Forwarded to the Home Manager module. |
| `dotfiles.localPath` | `str` | `""` | Forwarded to the Home Manager module when mutable mode is enabled. |

---

## Updating this flake when used as an input

In the consuming repo:

```bash
nix flake update dotfiles
```

Then rebuild with either `nixos-rebuild` or `home-manager switch`, depending on how you consume it.

---

## Testing

This flake includes an [nmt](https://git.sr.ht/~rycee/nmt) unit test suite and a NixOS VM integration test for the installer.

**Run unit tests:**

```bash
nix run .#packages.x86_64-linux.tests
```

Pass `-l` to list all available tests, or a substring to filter by name:

```bash
nix run .#packages.x86_64-linux.tests -- -l
nix run .#packages.x86_64-linux.tests -- config
```

**Run the installer integration test (NixOS VM):**

```bash
nix build .#checks.x86_64-linux.installer-bootstrap
```

**Run all checks at once:**

```bash
nix flake check
```

## Development shell

This flake exposes a dev shell that prepares a temporary `$HOME` pointing the relevant tools at this checkout's `.config/`:

```bash
nix develop .#default
```

## Notes

- Files under `.config/` are discovered recursively at evaluation time, so new config subdirectories are picked up automatically on the next rebuild.
- Mutable mode updates existing files immediately, but adding or removing files still requires a rebuild.
