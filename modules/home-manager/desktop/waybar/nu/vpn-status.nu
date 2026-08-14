#!@nu@/bin/nu -n

# STUB (2 of 2). Pinned to bash in waybar.nix until this is written.
#
# vpn-status.sh kept ACTIVE and TOOLTIPS as two arrays synced by index; the
# table below is the same data as one list of records. Filter it and emit:
#
#   connected -> {"text":" TAIL/PIA","alt":"connected",
#                 "tooltip":"Tailscale: Connected\nPIA VPN: Connected",
#                 "class":"connected"}
#   none      -> {"text":" off","alt":"disconnected",
#                 "tooltip":"No VPN active","class":"disconnected"}
#
# Both `text` values start with a literal space. Labels join with "/",
# tooltips with a newline. The bash version emitted a literal backslash-n
# because waybar renders it; `to json` escapes a real newline to the same
# thing, so either should work, but check it against the running bar.

def active? [unit: string] {
  (^@systemd@/bin/systemctl is-active $unit | complete).exit_code == 0
}

let vpns = [
  {label: "TAIL", tooltip: "Tailscale: Connected", on: ((^@tailscale@/bin/tailscale status | complete).exit_code == 0)}
  {label: "PIA", tooltip: "PIA VPN: Connected", on: (active? "pia-vpn.service")}
  {label: "TU", tooltip: "TU Wien VPN: Connected", on: (active? "openconnect-tuwien.service")}
]

# TODO: filter to the connected ones and emit the record above.
# `where`, `get`, `str join`, `is-empty` and `to json --raw` are the toolkit.
