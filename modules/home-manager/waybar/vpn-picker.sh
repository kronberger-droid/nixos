#!/usr/bin/env bash

# File to store last selected VPN
LAST_VPN_FILE="$HOME/.cache/last-vpn-region"

# Check if TU Wien VPN is active
TUWIEN_ACTIVE=$(systemctl is-active openconnect-tuwien.service >/dev/null 2>&1 && echo "yes" || echo "no")

# Check if any PIA VPN is active
ACTIVE_PIA=$(systemctl list-units --state=active --no-pager "openvpn-*" 2>/dev/null | grep -oP 'openvpn-\K[^.]+' | head -1)

# Get list of all available PIA regions
PIA_REGIONS=$(find /etc/systemd/system/ -name 'openvpn-*.service' -exec basename {} .service \; 2>/dev/null | sed 's/openvpn-//' | sort)

# Build menu
MENU=""

# Add disconnect option if any VPN is active
if [ "$TUWIEN_ACTIVE" = "yes" ]; then
    MENU="Disconnect from TU Wien VPN\n"
elif [ -n "$ACTIVE_PIA" ]; then
    REGION_NAME=$(echo "$ACTIVE_PIA" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
    MENU="Disconnect from PIA $REGION_NAME\n"
fi

# Add university VPN option
MENU="$MENU🎓 TU Wien VPN\n---\n"

# Add PIA regions
MENU="$MENU$PIA_REGIONS"

# Show rofi menu and get selection
SELECTED=$(echo -e "$MENU" | rofi -dmenu -i -p "Select VPN" -theme-str 'window {width: 400px;} listview {lines: 15;}')

# Exit if no selection
if [ -z "$SELECTED" ]; then
    exit 0
fi

# Handle disconnect options
if [[ "$SELECTED" == "Disconnect from TU Wien VPN" ]]; then
    /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
    notify-send "VPN" "Disconnected from TU Wien VPN" -i network-vpn-disconnected
    pkill -RTMIN+8 waybar 2>/dev/null || true
    exit 0
elif [[ "$SELECTED" == "Disconnect"* ]]; then
    /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia stop "$ACTIVE_PIA"
    notify-send "VPN" "Disconnected from PIA" -i network-vpn-disconnected
    pkill -RTMIN+8 waybar 2>/dev/null || true
    exit 0
fi

# Skip separator
if [[ "$SELECTED" == "---" ]]; then
    exit 0
fi

# Disconnect any active VPN first
if [ "$TUWIEN_ACTIVE" = "yes" ]; then
    /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service 2>/dev/null
fi
if [ -n "$ACTIVE_PIA" ]; then
    /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia stop "$ACTIVE_PIA" 2>/dev/null
fi

# Handle TU Wien VPN selection
if [[ "$SELECTED" == "TU Wien VPN" ]]; then
    notify-send "VPN" "Connecting to TU Wien VPN..." -i network-vpn
    /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start openconnect-tuwien.service

    # Check if connection was successful
    sleep 3
    if systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
        notify-send "VPN" "Connected to TU Wien VPN" -i network-vpn
        echo "tuwien" > "$LAST_VPN_FILE"
    else
        notify-send "VPN" "Failed to connect to TU Wien VPN" -i dialog-error
    fi
    exit 0
fi

# Handle PIA VPN selection
REGION_NAME=$(echo "$SELECTED" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
notify-send "VPN" "Connecting to PIA $REGION_NAME..." -i network-vpn
/run/wrappers/bin/pkexec /run/current-system/sw/bin/pia start "$SELECTED"

# Check if connection was successful
sleep 3
if systemctl is-active "openvpn-$SELECTED.service" >/dev/null 2>&1; then
    notify-send "VPN" "Connected to PIA $REGION_NAME" -i network-vpn
    echo "$SELECTED" > "$LAST_VPN_FILE"
else
    notify-send "VPN" "Failed to connect to PIA $REGION_NAME" -i dialog-error
fi
