#!@bash@/bin/bash

MODE=$(@mako@/bin/makoctl mode)
if echo "$MODE" | @ripgrep@/bin/rg -q "do-not-disturb"; then
    echo '{"text":"\uf1f6","alt":"on","tooltip":"Do Not Disturb: ON","class":"on"}'
else
    echo '{"text":"\uf0f3","alt":"off","tooltip":"Do Not Disturb: OFF","class":"off"}'
fi
