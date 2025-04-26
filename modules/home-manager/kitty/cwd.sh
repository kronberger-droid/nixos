#!/usr/bin/env bash
# Print working directory of the focused Sway window, or $HOME.

pid=$(swaymsg -t get_tree | jq -r \
      '.. | select(.type?) | select(.type=="con") | select(.focused==true).pid')
ppid=$(pgrep --newest --parent "$pid")

cwd=$(readlink "/proc/${ppid}/cwd" 2>/dev/null || true)

echo "${cwd:-$HOME}"
