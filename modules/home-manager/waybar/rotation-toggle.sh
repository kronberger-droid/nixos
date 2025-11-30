#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/rotation-state"
mkdir -p "$HOME/.cache"

# Toggle state
if [ -f "$STATE_FILE" ]; then
    # Rotation was disabled, enable it
    rm -f "$STATE_FILE"
    # Kill any existing rot8 processes and start fresh
    pkill -9 rot8 2>/dev/null || true
    sleep 0.2
    rot8 >/dev/null 2>&1 &
    notify-send "Auto-Rotation" "Enabled" -i rotation-allowed-symbolic
else
    # Rotation was enabled, disable it
    touch "$STATE_FILE"
    pkill -9 rot8 2>/dev/null || true
    notify-send "Auto-Rotation" "Disabled" -i rotation-locked-symbolic
fi

# Give it a moment to update, then signal waybar
sleep 0.3
pkill -RTMIN+9 waybar 2>/dev/null || true
