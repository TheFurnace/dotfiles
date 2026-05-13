#!/usr/bin/env bash

set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
container_user="dotfiles"
container_home="/home/$container_user"
container_runtime_dir="/tmp/runtime-$container_user"
container_script_path="/usr/local/bin/run-user-flow.sh"
container_path="$container_home/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ubuntu_release="${UBUNTU_RELEASE:-noble}"
ubuntu_mirror="${UBUNTU_MIRROR:-https://archive.ubuntu.com/ubuntu/}"
rootfs="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-nspawn.XXXXXX")"

cleanup() {
  sudo rm -rf "$rootfs"
}
trap cleanup EXIT

if [ ! -d /nix ]; then
  echo "/nix is required before running the nspawn flow." >&2
  exit 1
fi

if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
fi

sudo debootstrap \
  --variant=minbase \
  --include=ca-certificates,passwd,util-linux \
  "$ubuntu_release" \
  "$rootfs" \
  "$ubuntu_mirror"

sudo chmod 755 "$rootfs"

# Write the container setup script into the rootfs so nspawn does not need an
# interactive stdin stream to start the flow, and keep it out of /tmp because
# nspawn can mount a fresh tmpfs there.
sudo mkdir -p \
  "$rootfs/etc/profile.d" \
  "$rootfs/etc/fish/conf.d" \
  "$rootfs$(dirname "$container_script_path")" \
  "$rootfs$(dirname "$repo_root")"

sudo ln -sfn /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh "$rootfs/etc/profile.d/nix.sh"
sudo ln -sfn /nix/var/nix/profiles/default/etc/profile.d/nix.fish "$rootfs/etc/fish/conf.d/nix.fish"

sudo tee "$rootfs$container_script_path" >/dev/null <<'EOF'
set -euo pipefail

useradd --create-home --shell /bin/bash "$CONTAINER_USER"
container_user_uid="$(id -u "$CONTAINER_USER")"
container_user_gid="$(id -g "$CONTAINER_USER")"

mkdir -p -m 700 "$CONTAINER_RUNTIME_DIR"
chown "$CONTAINER_USER:$CONTAINER_USER" "$CONTAINER_RUNTIME_DIR"
chmod 700 "$CONTAINER_RUNTIME_DIR"

# Answers, in order:
# 1-4) accept username/home/state-version/system defaults
# 5) disable mutable mode
# 6) approve activation of the generated Home Manager configuration
printf '\n\n\n\nn\ny\n' >"$CONTAINER_HOME/install-answers.txt"

cat >"$CONTAINER_HOME/run-install.sh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

export HOME="$CONTAINER_HOME"
export LOGNAME="$CONTAINER_USER"
export PATH="$CONTAINER_PATH"
export TERM="xterm-256color"
export USER="$CONTAINER_USER"
export XDG_RUNTIME_DIR="$CONTAINER_RUNTIME_DIR"

exec bash "$DOTFILES_REPO/install.sh"
SCRIPT

cat >"$CONTAINER_HOME/validate-pwsh.ps1" <<'SCRIPT'
$ErrorActionPreference = "Stop"

Get-Command nix, oh-my-posh | Out-Null

if (-not ((Get-Content Function:\prompt -Raw) -match "oh-my-posh")) {
    throw "PowerShell prompt was not initialized by oh-my-posh."
}
SCRIPT

chmod +x "$CONTAINER_HOME/run-install.sh"
chown "$CONTAINER_USER:$CONTAINER_USER" \
  "$CONTAINER_HOME/install-answers.txt" \
  "$CONTAINER_HOME/run-install.sh" \
  "$CONTAINER_HOME/validate-pwsh.ps1"

run_as_user() (
  export HOME="$CONTAINER_HOME"
  export LOGNAME="$CONTAINER_USER"
  export PATH="$CONTAINER_PATH"
  export TERM="xterm-256color"
  export USER="$CONTAINER_USER"
  export XDG_RUNTIME_DIR="$CONTAINER_RUNTIME_DIR"

  exec setpriv --reuid "$container_user_uid" --regid "$container_user_gid" --init-groups "$@"
)

run_install_command_args=(
  setpriv
  --reuid "$container_user_uid"
  --regid "$container_user_gid"
  --init-groups
  /bin/bash
  "$CONTAINER_HOME/run-install.sh"
)
run_install_command=""
for run_install_arg in "${run_install_command_args[@]}"; do
  printf -v quoted_run_install_arg '%q' "$run_install_arg"
  if [ -n "$run_install_command" ]; then
    run_install_command+=" "
  fi
  run_install_command+="$quoted_run_install_arg"
done

script \
  --quiet \
  --return \
  --flush \
  --command "$run_install_command" \
  "$CONTAINER_HOME/install-transcript.txt" \
  <"$CONTAINER_HOME/install-answers.txt"

grep -Fq "Activate this Home Manager configuration now [y/N]:" "$CONTAINER_HOME/install-transcript.txt"
[ -f "$CONTAINER_HOME/.config/powershell/Microsoft.PowerShell_profile.ps1" ]
[ -f "$CONTAINER_HOME/.config/git/config" ]

run_as_user fish -lic 'command -sq nix; and command -sq oh-my-posh; and functions -q _omp_hook'
run_as_user bash -lic 'command -v nix >/dev/null && command -v oh-my-posh >/dev/null && declare -F _omp_hook >/dev/null'
run_as_user pwsh -NoLogo -File "$CONTAINER_HOME/validate-pwsh.ps1"
run_as_user nvim --headless '+quitall'

[ "$(run_as_user git config --get alias.adog)" = "log --all --decorate --oneline --graph" ]
[ "$(run_as_user git config --get core.editor)" = "nvim" ]
EOF
sudo chmod 755 "$rootfs$container_script_path"

binds=(
  --bind-ro=/nix
  --bind-ro="$repo_root:$repo_root"
)

if [ -d /etc/nix ]; then
  binds+=(--bind-ro=/etc/nix)
fi

sudo systemd-nspawn \
  --quiet \
  --console=pipe \
  --timezone=off \
  --directory="$rootfs" \
  "${binds[@]}" \
  --setenv=DOTFILES_REPO="$repo_root" \
  --setenv=CONTAINER_HOME="$container_home" \
  --setenv=CONTAINER_PATH="$container_path" \
  --setenv=CONTAINER_RUNTIME_DIR="$container_runtime_dir" \
  --setenv=CONTAINER_USER="$container_user" \
  /bin/bash "$container_script_path"
