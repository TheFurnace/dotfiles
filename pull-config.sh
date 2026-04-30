#!/usr/bin/env bash
# pull-config.sh — copy new regular files from ~/.config into ./dotfiles/.config
#
# Compares the live config tree against this repo's .config tree and only pulls
# files that do not already exist in the repo. Existing files are left untouched.
# Symlinks are ignored so mutable-mode links back into this repo are not copied.
#
# Usage:
#   ./pull-config.sh [--apply] [path ...]
#
# Defaults to a dry run. Pass --apply to copy and stage files.
# Paths may be absolute or relative to ~/.config/. With no paths, the entire
# ~/.config tree is scanned.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
DST_ROOT="$DOTFILES/.config"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

usage() {
    echo "Usage: $(basename "$0") [--apply] [path ...]"
    echo "  Dry-run by default; pass --apply to copy and stage files"
    echo "  Accepts absolute paths or paths relative to ~/.config/"
}

err() {
    echo "error: $*" >&2
}

DRY_RUN=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            DRY_RUN=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            err "unknown flag: $1"
            usage >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

paths=()
if [[ $# -eq 0 ]]; then
    paths+=("$SRC_ROOT")
else
    for path in "$@"; do
        if [[ "$path" != /* ]]; then
            path="$SRC_ROOT/$path"
        fi

        if [[ ! -e "$path" && ! -L "$path" ]]; then
            err "path does not exist: $path"
            exit 1
        fi

        case "$path" in
            "$SRC_ROOT"|"$SRC_ROOT"/*)
                paths+=("$path")
                ;;
            *)
                err "path is not under ~/.config: $path"
                exit 1
                ;;
        esac
    done
fi

copied=0
skipped=0

printf "${BOLD}~/.config${RESET}\n"

while IFS= read -r -d '' src; do
    rel="${src#$SRC_ROOT/}"
    dst="$DST_ROOT/$rel"

    if [[ -e "$dst" || -L "$dst" ]]; then
        printf "${YELLOW}·${RESET} %s\n" "$rel"
        (( skipped += 1 ))
        continue
    fi

    mkdir -p "$(dirname "$dst")"

    if (( DRY_RUN )); then
        printf "${GREEN}+${RESET} %s\n" "$rel"
    else
        cp -a "$src" "$dst"
        git -C "$DOTFILES" add -f ".config/$rel"
        printf "${GREEN}✓${RESET} %s\n" "$rel"
    fi

    (( copied += 1 ))
done < <(
    for path in "${paths[@]}"; do
        if [[ -d "$path" ]]; then
            find "$path" -type f -print0
        elif [[ -f "$path" ]]; then
            printf '%s\0' "$path"
        fi
    done | sort -z -u
)

echo
if (( DRY_RUN )); then
    if (( copied == 0 )); then
        printf "${YELLOW}no new files to pull${RESET}\n"
    else
        printf "${GREEN}%d would pull${RESET}" "$copied"
        printf "  "
        printf "${YELLOW}%d already in dotfiles${RESET}\n" "$skipped"
    fi
else
    if (( copied == 0 )); then
        printf "${YELLOW}no new files to pull${RESET}\n"
    else
        printf "${GREEN}%d pulled & staged${RESET}" "$copied"
        printf "  "
        printf "${YELLOW}%d already in dotfiles${RESET}\n" "$skipped"
        printf "run: git -C %s commit\n" "$DOTFILES"
    fi
fi
