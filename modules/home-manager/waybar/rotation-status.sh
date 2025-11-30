#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/rotation-state"

# If state file exists, rotation is disabled
if [ -f "$STATE_FILE" ]; then
    echo '{"text":"","alt":"disabled","tooltip":"Auto-rotation disabled (click to enable)","class":"disabled"}'
else
    echo '{"text":"","alt":"enabled","tooltip":"Auto-rotation enabled (click to disable)","class":"enabled"}'
fi
