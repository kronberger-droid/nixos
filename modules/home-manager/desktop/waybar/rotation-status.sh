#!@bash@/bin/bash

# Check if rotation is disabled (state file exists)
if [ -f "$HOME/.cache/rotation-state" ]; then
    echo '{"icon":"disabled","alt":"disabled","tooltip":"Auto-rotation Disabled","class":"disabled"}'
else
    echo '{"icon":"enabled","alt":"enabled","tooltip":"Auto-rotation Enabled","class":"enabled"}'
fi
