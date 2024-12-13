#!/usr/bin/env bash

# Get the current working directory of the focused window
current_dir=$(pwd)

# Fallback to home directory if cwd is empty
current_dir=${current_dir:-$HOME}

# Launch kitty in the determined directory
${HOME}/.nix-profile/bin/kitty --directory "$current_dir"
