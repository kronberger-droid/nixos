#!/usr/bin/env sh

mkdir -p "$HOME/.local/state"

# Generate a lockfile based on the command name
CMD_NAME=$(basename "$1")
LOCKFILE="$HOME/.local/state/${CMD_NAME}.lock"

# Kills the process if it's already running
lsof -Fp "$LOCKFILE" | sed 's/^p//' | xargs -r kill

flock --verbose -n "$LOCKFILE" "$@"
