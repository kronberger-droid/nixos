#!/usr/bin/env bash
# Actions only. The decision of *whether* to confirm lives in eww.yuck;
# by the time we get here the answer was yes.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

dismiss() {
  eww -c "$dir" update pending=none || true
  eww -c "$dir" close powermenu || true
}

case "${1:-}" in
  lock)
    dismiss
    swaylock -f
    ;;
  suspend)
    dismiss
    mpc -q pause 2>/dev/null || true
    amixer set Master mute 2>/dev/null || true
    systemctl suspend
    ;;
  hibernate)
    dismiss
    systemctl hibernate
    ;;
  reboot)
    dismiss
    systemctl reboot
    ;;
  shutdown)
    dismiss
    systemctl poweroff
    ;;
  logout)
    dismiss
    if [[ -n "${NIRI_SOCKET:-}" ]]; then
      niri msg action quit
    elif [[ -n "${SWAYSOCK:-}" ]]; then
      swaymsg exit
    fi
    ;;
  *)
    echo "usage: power.sh {lock|suspend|hibernate|reboot|shutdown|logout}" >&2
    exit 1
    ;;
esac
