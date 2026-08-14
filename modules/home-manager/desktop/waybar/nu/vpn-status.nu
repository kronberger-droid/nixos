#!@nu@/bin/nu -n

# One row per VPN rather than the bash version's two index-synced arrays, so
# filtering cannot misalign a label from its tooltip. The leading space in
# `text` is load-bearing for the bar's spacing.

def active? [unit: string] {
  (^@systemd@/bin/systemctl is-active $unit | complete).exit_code == 0
}

let vpns = [
  {label: "TAIL", tooltip: "Tailscale: Connected", on: ((^@tailscale@/bin/tailscale status | complete).exit_code == 0)}
  {label: "PIA", tooltip: "PIA VPN: Connected", on: (active? "pia-vpn.service")}
  {label: "TU", tooltip: "TU Wien VPN: Connected", on: (active? "openconnect-tuwien.service")}
]

let up = ($vpns | where on)

let labels = ($up | get label | str join "/")
let tooltips = ($up | get tooltip | str join "\n")

if ($up | is-empty) {
  {text: " off", alt: "disconnected", tooltip: "No VPN active", class: "disconnected"}
} else {
  {text: $" ($labels)", alt: "connected", tooltip: $tooltips, class: "connected"}
} | to json --raw
