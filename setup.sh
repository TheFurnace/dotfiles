#!/usr/bin/env bash
# setup.sh — symlink all .config files into ~/.config
#
# Creates one symlink per file, mirroring the directory structure.
# Existing regular files are backed up with a .bak extension before linking.
# Existing symlinks are silently updated.
# Run any number of times safely.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/.config"
DST="${XDG_CONFIG_HOME:-$HOME/.config}"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

linked=0
backed_up=0
skipped=0

while IFS= read -r -d '' src; do
    rel="${src#$SRC/}"
    dst="$DST/$rel"

    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ]; then
        # Already a symlink — update it
        ln -sf "$src" "$dst"
        printf "${GREEN}linked${RESET}    %s\n" "$rel"
        (( linked++ ))
    elif [ -e "$dst" ]; then
        # Regular file — back it up first
        mv "$dst" "$dst.bak"
        ln -s "$src" "$dst"
        printf "${YELLOW}backed up${RESET} %s  →  %s.bak\n" "$rel" "$rel"
        (( backed_up++ ))
        (( linked++ ))
    else
        ln -s "$src" "$dst"
        printf "${GREEN}linked${RESET}    %s\n" "$rel"
        (( linked++ ))
    fi
done < <(find "$SRC" -type f -print0 | sort -z)

echo
echo "$linked linked  $backed_up backed up  $skipped skipped"
