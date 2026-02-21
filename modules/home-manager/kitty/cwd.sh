#!/usr/bin/env bash
# Print working directory of the focused window, or $HOME.
# Only uses cwd for terminals and file managers, not browsers/other apps.
# Supports both sway and niri.

if [ -n "$SWAYSOCK" ]; then
    focused=$(swaymsg -t get_tree | jq -r \
          '.. | select(.type?) | select(.type=="con") | select(.focused==true)')
    app_id=$(echo "$focused" | jq -r '.app_id // empty')
    pid=$(echo "$focused" | jq -r '.pid')
elif [ -n "$NIRI_SOCKET" ]; then
    focused=$(niri msg -j focused-window)
    app_id=$(echo "$focused" | jq -r '.app_id // empty')
    pid=$(echo "$focused" | jq -r '.pid')
else
    echo "$HOME"
    exit 0
fi

# Apps where cwd is relevant (terminals, file managers, editors)
relevant_apps="kitty|foot|alacritty|wezterm|ghostty|nemo|nautilus|thunar|yazi|ranger|helix|nvim|vim|emacs|code|zed"

if [[ "$app_id" =~ ^($relevant_apps) ]]; then
    ppid=$(pgrep --newest --parent "$pid")
    cwd=$(readlink "/proc/${ppid}/cwd" 2>/dev/null || true)
    echo "${cwd:-$HOME}"
else
    echo "$HOME"
fi
