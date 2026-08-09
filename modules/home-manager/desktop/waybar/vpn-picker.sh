#!@bash@/bin/bash

NOTIFY="@libnotify@/bin/notify-send"
SIGNAL="@procps@/bin/pkill -RTMIN+8 waybar 2>/dev/null || true"
SUDO="/run/wrappers/bin/sudo"
SCTL="/run/current-system/sw/bin/systemctl"

# Check current state of each VPN
TAIL_ON=$(@tailscale@/bin/tailscale status >/dev/null 2>&1 && echo "yes" || echo "no")
PIA_ON=$(@systemd@/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1 && echo "yes" || echo "no")
TU_ON=$(@systemd@/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1 && echo "yes" || echo "no")

# Build menu with status indicators
MENU=""
[ "$TAIL_ON" = "yes" ] && MENU+="[ON]  Tailscale\n" || MENU+="[OFF] Tailscale\n"
[ "$PIA_ON"  = "yes" ] && MENU+="[ON]  PIA VPN\n"   || MENU+="[OFF] PIA VPN\n"
[ "$TU_ON"   = "yes" ] && MENU+="[ON]  TU Wien VPN" || MENU+="[OFF] TU Wien VPN"

SELECTED=$(echo -e "$MENU" | @rofi@/bin/rofi -dmenu -i -p "VPN" -theme-str 'window {width: 400px;} listview {lines: 3;}')

[ -z "$SELECTED" ] && exit 0

# Extract VPN name (strip "[ON]  " or "[OFF] " prefix)
VPN_NAME=$(echo "$SELECTED" | @sd@/bin/sd '^\[O[NF]*\] *' "")

case "$VPN_NAME" in
    Tailscale)
        if [ "$TAIL_ON" = "yes" ]; then
            @tailscale@/bin/tailscale down
            $NOTIFY "VPN" "Tailscale disconnected" -i network-vpn-disconnected
        else
            @tailscale@/bin/tailscale up
            $NOTIFY "VPN" "Tailscale connected" -i network-vpn
        fi
        ;;
    "PIA VPN")
        if [ "$PIA_ON" = "yes" ]; then
            $SUDO $SCTL stop pia-vpn.service
            $NOTIFY "VPN" "PIA VPN disconnected" -i network-vpn-disconnected
        else
            $NOTIFY "VPN" "Connecting to PIA VPN..." -i network-vpn
            $SUDO $SCTL start pia-vpn.service
            @coreutils@/bin/sleep 3
            if @systemd@/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
                $NOTIFY "VPN" "PIA VPN connected" -i network-vpn
            else
                $NOTIFY "VPN" "Failed to connect to PIA VPN" -i dialog-error
            fi
        fi
        ;;
    "TU Wien VPN")
        if [ "$TU_ON" = "yes" ]; then
            $SUDO $SCTL stop openconnect-tuwien.service
            $NOTIFY "VPN" "TU Wien VPN disconnected" -i network-vpn-disconnected
        else
            $NOTIFY "VPN" "Connecting to TU Wien VPN..." -i network-vpn
            $SUDO $SCTL start openconnect-tuwien.service
            @coreutils@/bin/sleep 3
            if @systemd@/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
                $NOTIFY "VPN" "TU Wien VPN connected" -i network-vpn
            else
                $NOTIFY "VPN" "Failed to connect to TU Wien VPN" -i dialog-error
            fi
        fi
        ;;
esac

@procps@/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
