# dotfiles

Plug-and-play dotfiles for Home Manager and NixOS.

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

Config files are sourced directly from `.config/`:

| Program | Source directory |
|---|---|
| Fish | `.config/fish/` |
| Git | `.config/git/` |
| Kitty | `.config/kitty/` |
| Neovim | `.config/nvim/` |
| oh-my-posh | `.config/oh-my-posh/` |

The fish prompt is wired automatically through `fish/conf.d/oh-my-posh.fish`, so after activation the prompt is ready to go.

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
          users.users.alice = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
          };

          dotfiles = {
            enable = true;
            username = "alice";
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
      username = "alice";
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
  username = "alice";
  stateVersion = "25.11";

  mutable = true;
  localPath = "/home/alice/repos/dotfiles";
};
```

In mutable mode, edits to existing files under `.config/` take effect immediately. Adding or removing files still requires a rebuild.

---

## Non-NixOS or standalone Home Manager

On non-NixOS, use `dotfiles.homeManagerModules.default`.

This installs the same user environment and wires fish + oh-my-posh automatically, but there is one platform limitation to be aware of:

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
      homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          dotfiles.homeManagerModules.default
          {
            dotfiles = {
              enable = true;
              username = "alice";
              homeDirectory = "/home/alice";
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
    homeConfigurations.alice = dotfiles.lib.mkHomeConfiguration {
      username = "alice";
      homeDirectory = "/home/alice";
      stateVersion = "25.11";
    };
  };
}
```

Apply it with:

```bash
git add -A
home-manager switch --flake .#alice
```

### One-time login shell step on non-NixOS

After the first activation, fish and oh-my-posh are installed and ready. If you also want your OS login shell to be fish, run:

```bash
chsh -s "$(command -v fish)"
```

Depending on the distro, the fish path may need to exist in `/etc/shells` first.

---

## Standalone configs bundled in this repo

This flake still exposes a personal standalone configuration at `.#ferndq`:

```bash
git add -A
nix flake check
home-manager switch --flake .#ferndq
```

But standalone usage is now less hard-coded because the flake also exports `dotfiles.lib.mkHomeConfiguration`, which lets another flake create a Home Manager configuration with just:

```nix
dotfiles.lib.mkHomeConfiguration {
  username = "alice";
  homeDirectory = "/home/alice";
  stateVersion = "25.11";
}
```

The helper also supports:

- `system`
- `mutable`
- `localPath`
- `extraModules`

## NixOS helper options: `lib.mkNixosConfiguration`

`mkNixosConfiguration` accepts:

- `hostname`
- `username`
- `homeDirectory` (optional; defaults to `users.users.<name>.home`, or `/home/${username}` if unset)
- `stateVersion` for Home Manager
- `nixosStateVersion` (defaults to `stateVersion`)
- `system`
- `mutable`
- `localPath`
- `user` for extra `users.users.<name>` fields
- `extraModules`

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
| `dotfiles.homeDirectory` | `null or str` | `null` | Optional home directory override. Defaults to `users.users.<name>.home`, or `/home/<name>` if unset. |
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

## Notes

- Do not enable `programs.fish` separately in the Home Manager user config that imports `homeManagerModules.default`. This repo owns `fish/config.fish` directly through `xdg.configFile`.
- Files under `.config/` are discovered recursively at evaluation time, so new config subdirectories are picked up automatically on the next rebuild.
- Mutable mode updates existing files immediately, but adding or removing files still requires a rebuild.
