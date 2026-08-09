#!@bash@/bin/bash

MODE=$(@mako@/bin/makoctl mode)
if echo "$MODE" | @ripgrep@/bin/rg -q "do-not-disturb"; then
    @mako@/bin/makoctl mode -r do-not-disturb
    @libnotify@/bin/notify-send "Do Not Disturb" "Notifications enabled" -i notification
else
    @mako@/bin/makoctl mode -s do-not-disturb
fi
@procps@/bin/pkill -RTMIN+11 waybar 2>/dev/null || true
