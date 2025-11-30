#!/usr/bin/env bash

# File to store last used VPN
LAST_VPN_FILE="$HOME/.cache/last-vpn-region"
DEFAULT_VPN="austria"

# Check if TU Wien VPN is active
if systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
    # TU Wien VPN is connected, disconnect it
    /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
    notify-send "VPN" "Disconnected from TU Wien VPN" -i network-vpn-disconnected
    pkill -RTMIN+8 waybar 2>/dev/null || true
    exit 0
fi

# Check if any PIA VPN is currently active
ACTIVE_PIA=$(systemctl list-units --state=active --no-pager "openvpn-*" 2>/dev/null | grep -oP 'openvpn-\K[^.]+' | head -1)

if [ -n "$ACTIVE_PIA" ]; then
    # PIA VPN is connected, disconnect it
    REGION_NAME=$(echo "$ACTIVE_PIA" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
    /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia stop "$ACTIVE_PIA"
    notify-send "VPN" "Disconnected from PIA $REGION_NAME" -i network-vpn-disconnected
    pkill -RTMIN+8 waybar 2>/dev/null || true
    exit 0
fi

# No VPN is connected, connect to last used VPN
LAST_VPN="$DEFAULT_VPN"
if [ -f "$LAST_VPN_FILE" ]; then
    LAST_VPN=$(cat "$LAST_VPN_FILE")
fi

# Check if last VPN was TU Wien
if [ "$LAST_VPN" = "tuwien" ]; then
    notify-send "VPN" "Connecting to TU Wien VPN..." -i network-vpn
    /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl start openconnect-tuwien.service

    # Check if connection was successful
    sleep 3
    if systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
        notify-send "VPN" "Connected to TU Wien VPN" -i network-vpn
    else
        notify-send "VPN" "Failed to connect to TU Wien VPN" -i dialog-error
    fi
    pkill -RTMIN+8 waybar 2>/dev/null || true
else
    # Connect to PIA region
    REGION_NAME=$(echo "$LAST_VPN" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
    notify-send "VPN" "Connecting to PIA $REGION_NAME..." -i network-vpn
    /run/wrappers/bin/pkexec /run/current-system/sw/bin/pia start "$LAST_VPN"

    # Check if connection was successful
    sleep 3
    if systemctl is-active "openvpn-$LAST_VPN.service" >/dev/null 2>&1; then
        notify-send "VPN" "Connected to PIA $REGION_NAME" -i network-vpn
    else
        notify-send "VPN" "Failed to connect to PIA $REGION_NAME" -i dialog-error
    fi
    pkill -RTMIN+8 waybar 2>/dev/null || true
fi
