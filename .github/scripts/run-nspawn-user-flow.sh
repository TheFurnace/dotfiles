#!/usr/bin/env bash

set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
container_user="dotfiles"
container_home="/home/$container_user"
container_script_path="/usr/local/bin/prepare-user-flow.sh"
host_nix_profile="${HOME}/.nix-profile"
host_user_uid="$(id -u)"
host_user_gid="$(id -g)"
container_path="$container_home/.nix-profile/bin:$host_nix_profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ubuntu_release="${UBUNTU_RELEASE:-noble}"
ubuntu_mirror="${UBUNTU_MIRROR:-https://archive.ubuntu.com/ubuntu/}"
rootfs="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-nspawn.XXXXXX")"
machine_name="dotfiles-user-flow-$$"
nspawn_pid=""

cleanup() {
  if [ -n "$nspawn_pid" ]; then
    sudo machinectl poweroff "$machine_name" >/dev/null 2>&1 || true
    wait "$nspawn_pid" || true
  fi
  sudo rm -rf "$rootfs"
}
trap cleanup EXIT

run_in_machine() {
  sudo systemd-run \
    --quiet \
    --wait \
    --pipe \
    --collect \
    --machine="$machine_name" \
    "$@"
}

wait_for_machine() {
  local timeout_seconds="${1:-120}"
  local deadline=$((SECONDS + timeout_seconds))

  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ -n "$nspawn_pid" ] && ! kill -0 "$nspawn_pid" >/dev/null 2>&1; then
      local wait_status=0
      wait "$nspawn_pid" || wait_status=$?
      echo "$machine_name exited unexpectedly with status $wait_status." >&2
      exit 1
    fi

    if run_in_machine /bin/true >/dev/null 2>&1; then
      return
    fi

    sleep 1
  done

  echo "Timed out waiting for $machine_name to finish booting." >&2
  exit 1
}

if [ ! -d /nix ]; then
  echo "/nix is required before running the nspawn flow." >&2
  exit 1
fi

if [ ! -d "$host_nix_profile" ]; then
  echo "Host Nix profile is required before running the nspawn flow: $host_nix_profile" >&2
  exit 1
fi

if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
fi

sudo debootstrap \
  --variant=minbase \
  --include=ca-certificates,dbus,passwd,systemd-sysv,util-linux \
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
  "$rootfs$(dirname "$host_nix_profile")" \
  "$rootfs$(dirname "$repo_root")"

sudo ln -sfn "$host_nix_profile/etc/profile.d/nix-daemon.sh" "$rootfs/etc/profile.d/nix.sh"
sudo ln -sfn "$host_nix_profile/etc/profile.d/nix.fish" "$rootfs/etc/fish/conf.d/nix.fish"

sudo tee "$rootfs$container_script_path" >/dev/null <<'EOF'
set -euo pipefail

if ! getent group "$HOST_GID" >/dev/null; then
  groupadd --gid "$HOST_GID" "${CONTAINER_USER}-host"
fi

useradd --create-home --shell /bin/bash --uid "$HOST_UID" --gid "$HOST_GID" "$CONTAINER_USER"
container_user_uid="$(id -u "$CONTAINER_USER")"
container_user_gid="$(id -g "$CONTAINER_USER")"
loginctl enable-linger "$CONTAINER_USER"

# Answers, in order:
# 1-4) accept username/home/state-version/system defaults
# 5) disable mutable mode
# 6) approve activation of the generated Home Manager configuration
printf '\n\n\n\nn\ny\n' >"$CONTAINER_HOME/install-answers.txt"

cat >"$CONTAINER_HOME/run-install.sh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

exec bash "$DOTFILES_REPO/install.sh"
SCRIPT

cat >"$CONTAINER_HOME/run-user-flow.sh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

: "${DOTFILES_REPO:?}"
: "${CONTAINER_PATH:?}"
: "${XDG_RUNTIME_DIR:?}"
: "${HOME:?}"

export PATH="$CONTAINER_PATH"

if [[ "$HOME" != "/home/dotfiles" ]]; then
  printf 'Expected HOME to be %s, got %s\n' "/home/dotfiles" "$HOME" >&2
  exit 1
fi

expected_runtime_dir="/run/user/$(id -u)"
if [[ "$XDG_RUNTIME_DIR" != "$expected_runtime_dir" ]]; then
  printf 'Expected XDG_RUNTIME_DIR to be %s, got %s\n' "$expected_runtime_dir" "$XDG_RUNTIME_DIR" >&2
  exit 1
fi

require_transcript_line() {
  local needle="$1"
  grep -aF "$needle" "$HOME/install-transcript.txt"
}

script \
  --quiet \
  --return \
  --flush \
  --command "/bin/bash \"$HOME/run-install.sh\"" \
  "$HOME/install-transcript.txt" \
  <"$HOME/install-answers.txt"

require_transcript_line "Installing standalone Home Manager config from:" >/dev/null
require_transcript_line "Running nix flake check for:" >/dev/null
require_transcript_line "Building the generated Home Manager activation package..." >/dev/null
require_transcript_line "Activate this Home Manager configuration now [y/N]:" >/dev/null
require_transcript_line "Starting Home Manager activation" >/dev/null
require_transcript_line "Creating home file links in $HOME" >/dev/null
if grep -aFq "Skipping activation." "$HOME/install-transcript.txt"; then
  echo "install.sh skipped activation unexpectedly." >&2
  exit 1
fi

echo "Validated install transcript markers:"
require_transcript_line "Running nix flake check for:"
require_transcript_line "Building the generated Home Manager activation package..."
require_transcript_line "Activate this Home Manager configuration now [y/N]:"
require_transcript_line "Starting Home Manager activation"
require_transcript_line "Creating home file links in $HOME"
test -d "$XDG_RUNTIME_DIR"
test -f "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
test -f "$HOME/.config/git/config"
SCRIPT

cat >"$CONTAINER_HOME/validate-pwsh.ps1" <<'SCRIPT'
$ErrorActionPreference = "Stop"

Get-Command nix, oh-my-posh | Out-Null

if (-not ((Get-Content Function:\prompt -Raw) -match "oh-my-posh")) {
    throw "PowerShell prompt was not initialized by oh-my-posh."
}
SCRIPT

chmod +x "$CONTAINER_HOME/run-install.sh" "$CONTAINER_HOME/run-user-flow.sh"
chown "$container_user_uid:$container_user_gid" \
  "$CONTAINER_HOME/install-answers.txt" \
  "$CONTAINER_HOME/run-install.sh" \
  "$CONTAINER_HOME/run-user-flow.sh" \
  "$CONTAINER_HOME/validate-pwsh.ps1"
EOF
sudo chmod 755 "$rootfs$container_script_path"

binds=(
  --bind=/nix
  --bind-ro="$host_nix_profile:$host_nix_profile"
  --bind-ro="$repo_root:$repo_root"
)

if [ -d /etc/nix ]; then
  binds+=(--bind-ro=/etc/nix)
fi

if [ -d /etc/ssl/certs ]; then
  binds+=(--bind-ro=/etc/ssl/certs)
fi

sudo systemd-nspawn \
  --quiet \
  --boot \
  --console=passive \
  --machine="$machine_name" \
  --timezone=off \
  --directory="$rootfs" \
  "${binds[@]}" \
  --setenv=DOTFILES_REPO="$repo_root" \
  --setenv=CONTAINER_HOME="$container_home" \
  --setenv=CONTAINER_PATH="$container_path" \
  --setenv=CONTAINER_USER="$container_user" \
  --setenv=HOST_UID="$host_user_uid" \
  --setenv=HOST_GID="$host_user_gid" \
  --setenv=NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  --setenv=SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  &
nspawn_pid=$!

wait_for_machine
run_in_machine \
  env \
  DOTFILES_REPO="$repo_root" \
  CONTAINER_HOME="$container_home" \
  CONTAINER_USER="$container_user" \
  HOST_UID="$host_user_uid" \
  HOST_GID="$host_user_gid" \
  /bin/bash "$container_script_path"
sudo machinectl shell \
  --quiet \
  --uid="$container_user" \
  --setenv=DOTFILES_REPO="$repo_root" \
  --setenv=CONTAINER_PATH="$container_path" \
  --setenv=PATH="$container_path" \
  --setenv=TERM="xterm-256color" \
  --setenv=XDG_RUNTIME_DIR="/run/user/$host_user_uid" \
  --setenv=NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  --setenv=SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  "$machine_name" \
  /bin/bash "$container_home/run-user-flow.sh"
run_in_machine grep -aFq "Running nix flake check for:" "$container_home/install-transcript.txt"
run_in_machine grep -aFq "Building the generated Home Manager activation package..." "$container_home/install-transcript.txt"
run_in_machine grep -aFq "Activate this Home Manager configuration now [y/N]:" "$container_home/install-transcript.txt"
run_in_machine grep -aFq "Starting Home Manager activation" "$container_home/install-transcript.txt"
run_in_machine grep -aFq "Creating home file links in $container_home" "$container_home/install-transcript.txt"
run_in_machine test -f "$container_home/.config/powershell/Microsoft.PowerShell_profile.ps1"
run_in_machine test -f "$container_home/.config/git/config"

sudo machinectl poweroff "$machine_name" >/dev/null
wait "$nspawn_pid"
nspawn_pid=""
