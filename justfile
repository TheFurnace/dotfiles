set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes.
default:
    @just --list

# Symlink repo-managed config files into ~/.config.
link:
    ./setup.sh

# Preview new regular files from ~/.config that are not yet in this repo.
pull +args:
    ./pull-config.sh {{args}}

# Copy and stage new regular files from ~/.config into this repo's .config tree.
pull-apply +args:
    ./pull-config.sh --apply {{args}}
