#!@bash@/bin/bash

STATE_FILE="$HOME/.cache/rotation-state"

# Toggle rotation state
if [ -f "$STATE_FILE" ]; then
    # Enable rotation
    @coreutils@/bin/rm -f "$STATE_FILE"
    @rot8@/bin/rot8 &
    @libnotify@/bin/notify-send "Auto-rotation" "Screen auto-rotation enabled" -i display-brightness
else
    # Disable rotation
    @coreutils@/bin/touch "$STATE_FILE"
    @procps@/bin/pkill rot8
    @libnotify@/bin/notify-send "Auto-rotation" "Screen auto-rotation disabled" -i display-brightness
fi

# Refresh waybar
@procps@/bin/pkill -RTMIN+9 waybar 2>/dev/null || true
