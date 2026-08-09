#!@bash@/bin/bash

ACTIVE=()
TOOLTIPS=()

# Check Tailscale
if @tailscale@/bin/tailscale status >/dev/null 2>&1; then
    ACTIVE+=("TAIL")
    TOOLTIPS+=("Tailscale: Connected")
fi

# Check PIA VPN
if @systemd@/bin/systemctl is-active pia-vpn.service >/dev/null 2>&1; then
    ACTIVE+=("PIA")
    TOOLTIPS+=("PIA VPN: Connected")
fi

# Check TU Wien VPN
if @systemd@/bin/systemctl is-active openconnect-tuwien.service >/dev/null 2>&1; then
    ACTIVE+=("TU")
    TOOLTIPS+=("TU Wien VPN: Connected")
fi

if [ ${#ACTIVE[@]} -gt 0 ]; then
    LABEL=$(IFS=/; echo "${ACTIVE[*]}")
    # Join tooltips with literal \n for waybar tooltip rendering
    TOOLTIP=""
    for i in "${!TOOLTIPS[@]}"; do
        [ -n "$TOOLTIP" ] && TOOLTIP+="\\n"
        TOOLTIP+="${TOOLTIPS[$i]}"
    done
    echo "{\"text\":\" $LABEL\",\"alt\":\"connected\",\"tooltip\":\"$TOOLTIP\",\"class\":\"connected\"}"
else
    echo '{"text":" off","alt":"disconnected","tooltip":"No VPN active","class":"disconnected"}'
fi
