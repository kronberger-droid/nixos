#!@bash@/bin/bash

NOTIFY="@libnotify@/bin/notify-send"
ANY_ACTIVE=false

# Disconnect Tailscale
if @tailscale@/bin/tailscale status >/dev/null 2>&1; then
    @tailscale@/bin/tailscale down
    ANY_ACTIVE=true
fi

# Disconnect PIA
if @systemd@/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
    /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop pia-vpn.service
    ANY_ACTIVE=true
fi

# Disconnect TU Wien
if @systemd@/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
    /run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl stop openconnect-tuwien.service
    ANY_ACTIVE=true
fi

if [ "$ANY_ACTIVE" = true ]; then
    $NOTIFY "VPN" "All VPNs disconnected" -i network-vpn-disconnected
else
    $NOTIFY "VPN" "No VPNs were active" -i network-vpn-disconnected
fi

@procps@/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
