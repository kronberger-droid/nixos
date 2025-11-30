#!/usr/bin/env bash

# Check if TU Wien VPN is active
if systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
    echo '{"text":" TU","alt":"connected","tooltip":"TU Wien VPN Connected","class":"connected"}'
    exit 0
fi

# Check if any PIA VPN is active
ACTIVE_VPN=$(systemctl list-units --state=active --no-pager "openvpn-*" 2>/dev/null | grep -oP 'openvpn-\K[^.]+' | head -1)

if [ -n "$ACTIVE_VPN" ]; then
    # PIA VPN is connected - format region name for display
    REGION_DISPLAY=$(echo "$ACTIVE_VPN" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
    # Map region names to proper ISO country codes
    case "$ACTIVE_VPN" in
        austria) SHORT="AT" ;;
        australia) SHORT="AU" ;;
        *) SHORT=$(echo "$ACTIVE_VPN" | cut -c1-2 | tr '[:lower:]' '[:upper:]') ;;
    esac
    echo "{\"text\":\" $SHORT\",\"alt\":\"connected\",\"tooltip\":\"PIA $REGION_DISPLAY Connected\",\"class\":\"connected\"}"
else
    # No VPN is connected
    echo '{"text":" off","alt":"disconnected","tooltip":"Click to toggle last VPN, right-click to choose","class":"disconnected"}'
fi
