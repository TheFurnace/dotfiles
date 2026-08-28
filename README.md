# dotfiles

A reusable Linux environment built with Nix and Home Manager.

The repository has two deliberately separate layers:

- **Nix core** — reproducible packages, shell configuration, editor settings,
  terminal configuration, and reusable Home Manager/NixOS modules.
- **Edge tools** — Pi and Codex are installed outside Nix by an explicit
  `dotfiles-ai` command so they can follow upstream releases without waiting
  for the flake lock to move.

The supported systems are `x86_64-linux` and `aarch64-linux`. The intended
deployment targets are NixOS, standalone Home Manager, and generic Linux
environments such as Debian, Ubuntu, and WSL.

## Use a clone directly

Clone the repository and edit [`defaults.nix`](defaults.nix) once for the
target user and machine:

```sh
git clone https://github.com/TheFurnace/dotfiles.git
cd dotfiles
$EDITOR defaults.nix
```

The file supplies the built-in `default` configurations while the exported
modules and constructors remain generic.

For standalone Home Manager, build and activate the configuration without
creating a second consumer flake:

```sh
nix build .#homeConfigurations.default.activationPackage
./result/activate
```

If the Home Manager CLI is already installed, the usual command is equivalent:

```sh
home-manager switch --flake .#default
```

On NixOS, first replace the tracked hardware placeholder with the configuration
generated for that machine. Add any other host-specific modules, including the
appropriate boot-loader configuration, to `nixosModules` in `defaults.nix`.
Then activate the direct NixOS target:

```sh
cp /etc/nixos/hardware-configuration.nix nixos/hardware-configuration.nix
$EDITOR defaults.nix
sudo nixos-rebuild switch --flake .#default
```

The tracked placeholder contains low-priority fallbacks for a conventional
UEFI system with an ext4 root labelled `nixos`, solely so a fresh clone remains
evaluable. Do not treat those as a substitute for the generated machine file.
The default output also provides the user, Home Manager environment, Fish login
shell, hostname, and state versions.

## Quick bootstrap

Cloning is optional for standalone Home Manager. The bootstrap app can instead
generate a small consumer flake that follows this repository:

The initial `nix run` must be executed by a Nix installation with flakes
enabled.

```sh
# Generate ~/.config/home-manager/flake.nix.
nix run github:TheFurnace/dotfiles -- init

# Generate the consumer flake and activate it.
nix run github:TheFurnace/dotfiles -- init --switch

# Activate and then explicitly install Pi and Codex from upstream.
nix run github:TheFurnace/dotfiles -- init --switch --with-ai
```

The installer is idempotent. It will not overwrite an existing Home Manager
flake, and it preserves unrelated settings in the user's `nix.conf`.

On non-NixOS Linux, activation installs `dotfiles-setup-shell`. Run the
suggested command once if Fish should become the login shell:

```sh
sudo ~/.nix-profile/bin/dotfiles-setup-shell fish
```

## Managing Pi and Codex

Nix installs the stable dependencies and the `dotfiles-ai` manager, but never
runs a network installer during Home Manager activation.

```sh
dotfiles-ai status
dotfiles-ai install all
dotfiles-ai update all
dotfiles-ai update pi
dotfiles-ai update codex
```

Pi is installed from the [official Pi installer](https://pi.dev/docs/latest).
Codex is installed and updated using the [official Codex standalone
installer](https://learn.chatgpt.com/docs/codex/cli). Because both commands run
remote upstream installers, they are always explicit user actions.

## Use as a standalone Home Manager module

```nix
{
  inputs.dotfiles.url = "github:TheFurnace/dotfiles";

  outputs = { dotfiles, ... }: {
    homeConfigurations.me = dotfiles.lib.mkHomeConfiguration {
      system = "x86_64-linux";
      username = "me";
      homeDirectory = "/home/me";
      stateVersion = "25.11";
    };
  };
}
```

For a smaller headless environment, disable optional feature groups:

```nix
features = {
  desktop.enable = false;
  development.enable = false;
  aiTools.enable = false;
};
```

## Use from NixOS

The helper provisions the user, imports Home Manager, and sets Fish as the
login shell:

```nix
{
  inputs.dotfiles.url = "github:TheFurnace/dotfiles";

  outputs = { dotfiles, ... }: {
    nixosConfigurations.workstation = dotfiles.lib.mkNixosConfiguration {
      system = "x86_64-linux";
      hostname = "workstation";
      username = "me";
      stateVersion = "25.11";
    };
  };
}
```

Lower-level consumers can import `homeManagerModules.default` or
`nixosModules.default` directly.

## Mutable development mode

Immutable mode is the default: configuration is copied through the Nix store.
Mutable mode creates out-of-store links to a checkout so edits to existing
files take effect without rebuilding:

```nix
mutable = true;
localPath = "/home/me/src/dotfiles";
```

Adding or removing a file still requires a Home Manager rebuild because the
set of managed paths changes.

## What is managed

The default feature set includes:

- Fish and Bash initialization, oh-my-posh, direnv, zoxide, and nix-your-shell
- Git, Neovim, ripgrep, and nix-index-database/comma
- Kitty and Fira Code (`features.desktop.enable`)
- language tooling, GitHub CLI, Python, and PowerShell
  (`features.development.enable`)
- tmux, jq, Python, and `dotfiles-ai` (`features.aiTools.enable`)

Files below `.config/` are discovered recursively and installed through
`xdg.configFile`. Fish configuration is expressed through Home Manager's
`programs.fish` module instead of a checked-in Fish directory.

Machine identity, secrets, Git author identity, and host-specific NixOS
configuration belong in the consuming repository.

## Outputs

| Output | Purpose |
|---|---|
| `homeManagerModules.default` | Reusable Home Manager module |
| `nixosModules.default` | NixOS integration around the Home Manager module |
| `lib.mkHomeConfiguration` | Standalone Home Manager constructor |
| `lib.mkNixosConfiguration` | NixOS system constructor |
| `homeConfigurations.default` | Direct standalone configuration from `defaults.nix` |
| `nixosConfigurations.default` | Direct NixOS configuration from `defaults.nix` |
| `apps.<system>.default` | Bootstrap and login-shell installer |
| `packages.<system>.tests` | nmt test runner |
| `checks.<system>.nmt` | Aggregate module test suite |
| `checks.x86_64-linux.direct-configurations` | Evaluation check for both direct defaults |
| `checks.x86_64-linux.installer-bootstrap` | Fresh-VM bootstrap test |

## Development and tests

```sh
# Enter an isolated development shell.
nix develop

# List or run the fast Home Manager module tests.
nix run .#packages.x86_64-linux.tests -- -l
nix run .#packages.x86_64-linux.tests

# Run one subset while iterating.
nix run .#packages.x86_64-linux.tests -- ai

# Validate the real bootstrap flow in a fresh NixOS VM.
nix build .#checks.x86_64-linux.installer-bootstrap

# Evaluate/build every check for the current system.
nix flake check
```

Use nmt tests for normal module/configuration work. Run the VM test when the
installer, generated consumer flake, or first-activation behavior changes.

See [docs/architecture.md](docs/architecture.md) for the design boundaries and
invariants.
