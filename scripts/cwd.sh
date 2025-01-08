#!/usr/bin/env bash

pid=$(swaymsg -t get_tree | jq -r '.. | select(.type?) | select(.type=="con") | select(.focused==true).pid')
ppid=$(pgrep --newest --parent ${pid})

# Try getting the working directory of the focused application
cwd=$(readlink /proc/${ppid}/cwd 2>/dev/null)

# If not a terminal, fallback to last terminal's directory or $HOME
if [ -z "$cwd" ]; then
    terminal_pid=$(pgrep --newest kitty)
    cwd=$(readlink /proc/${terminal_pid}/cwd 2>/dev/null)
fi

echo "${cwd:-$HOME}"
