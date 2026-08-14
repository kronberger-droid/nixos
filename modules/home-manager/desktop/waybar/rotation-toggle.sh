#!@bash@/bin/bash

# Behavioural twin of nu/rotation-toggle.nu; see the comment there for why the
# state file stays and systemd owns the process.
STATE_FILE="$HOME/.cache/rotation-state"

if [ -f "$STATE_FILE" ]; then
    @coreutils@/bin/rm -f "$STATE_FILE"
    # restart, not start: ExecCondition has to re-read the now-absent file.
    @systemd@/bin/systemctl --user restart rot8.service
    STATE=enabled
else
    @coreutils@/bin/touch "$STATE_FILE"
    @systemd@/bin/systemctl --user stop rot8.service
    STATE=disabled
fi

@libnotify@/bin/notify-send "Auto-rotation" "Screen auto-rotation $STATE" -i display-brightness

@procps@/bin/pkill -RTMIN+9 waybar 2>/dev/null || true
