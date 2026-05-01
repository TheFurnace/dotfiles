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
# Paths may be absolute or relative to ~/.config/, but they must live under a
# top-level entry that already exists in this repo's .config/. With no paths,
# the script scans only those matching managed subtrees.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
DST_ROOT="$DOTFILES/.config"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

usage() {
    echo "Usage: $(basename "$0") [--apply|-a] [path ...]"
    echo "  Dry-run by default; pass --apply or -a to copy and stage files"
    echo "  Accepts absolute paths or paths relative to ~/.config/"
    echo "  Flags may appear before or after paths"
    echo "  Only scans paths under top-level entries already present in ./.config/"
    echo "  Ignores empty repo subtrees; only managed entries with files are considered"
}

err() {
    echo "error: $*" >&2
}

DRY_RUN=1
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--apply)
            DRY_RUN=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            args+=("$@")
            break
            ;;
        -*)
            err "unknown flag: $1"
            usage >&2
            exit 1
            ;;
        *)
            args+=("$1")
            ;;
    esac
    shift
done

set -- "${args[@]}"

resolve_path() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1"
    else
        readlink -f "$1"
    fi
}

SRC_ROOT="$(resolve_path "$SRC_ROOT")"
DST_ROOT="$(resolve_path "$DST_ROOT")"

add_default_paths() {
    local top path

    for top in "${!managed_roots[@]}"; do
        path="$SRC_ROOT/$top"
        if [[ -e "$path" || -L "$path" ]]; then
            paths+=("$path")
        fi
    done
}

has_regular_files() {
    local path="$1"

    if [[ -f "$path" ]]; then
        return 0
    fi

    if [[ -d "$path" ]] && find "$path" -type f -print -quit | grep -q .; then
        return 0
    fi

    return 1
}

declare -A managed_roots=()
for managed_path in "$DST_ROOT"/*; do
    [[ -e "$managed_path" || -L "$managed_path" ]] || continue
    if has_regular_files "$managed_path"; then
        managed_roots["$(basename "$managed_path")"]=1
    fi
done

if (( ${#managed_roots[@]} == 0 )); then
    err "no managed entries with files found under $DST_ROOT"
    exit 1
fi

is_managed_path() {
    local path="$1"
    local rel top

    case "$path" in
        "$SRC_ROOT")
            return 0
            ;;
        "$SRC_ROOT"/*)
            rel="${path#$SRC_ROOT/}"
            top="${rel%%/*}"
            [[ -n "${managed_roots[$top]:-}" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

paths=()
if [[ $# -eq 0 ]]; then
    add_default_paths
else
    for path in "$@"; do
        if [[ "$path" != /* ]]; then
            path="$SRC_ROOT/$path"
        fi

        if [[ ! -e "$path" && ! -L "$path" ]]; then
            err "path does not exist: $path"
            exit 1
        fi

        path="$(resolve_path "$path")"

        case "$path" in
            "$SRC_ROOT")
                add_default_paths
                ;;
            "$SRC_ROOT"/*)
                if ! is_managed_path "$path"; then
                    err "path is not under a managed ~/.config subtree: $path"
                    exit 1
                fi
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

    if (( DRY_RUN )); then
        printf "${GREEN}+${RESET} %s\n" "$rel"
    else
        mkdir -p "$(dirname "$dst")"
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
