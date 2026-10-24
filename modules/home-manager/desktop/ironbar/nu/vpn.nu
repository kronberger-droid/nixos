#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# VPN status, menu contents, and toggling. Merged from three waybar helpers:
# vpn-status.nu (unchanged logic), vpn-picker.nu (minus its rofi call) and
# vpn-disconnect-all.nu.
#
# The picker was rofi -dmenu over three fixed entries, which is a lot of
# machinery for a three-item list. It is now a bar popup whose rows call
# `vpn toggle` and read the dots `refresh` pushes, so the whole interaction
# stays in the widget layer and matches the bar's styling for free.
#
# One row per VPN rather than the bash version's two index-synced arrays, so
# filtering cannot misalign a label from its tooltip. The leading space in
# `text` is load-bearing for the bar's spacing.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const BRIDGE      = "@bridge@"
const ON          = "@on@"
const OFF         = "@off@"
const NOTIFY_SEND = "@libnotify@/bin/notify-send"
const SYSTEMCTL   = "@systemd@/bin/systemctl"
const TAILSCALE   = "@tailscale@/bin/tailscale"

use "@barLib@" *

def active? [unit: string] {
  (^$SYSTEMCTL is-active $unit | complete).exit_code == 0
}

def notify [body: string, icon: string] {
  ^$NOTIFY_SEND "VPN" $body -i $icon | complete | ignore
}

def systemctl-user [verb: string, unit: string] {
  ^/run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl $verb $unit | complete | ignore
}

def tailscale-on? []: nothing -> bool {
  (^$TAILSCALE status | complete).exit_code == 0
}

# Tailscale has no systemd unit and no connect delay, so it carries an empty
# unit and is special-cased in `toggle`.
def entries []: nothing -> list {
  [
    {name: "Tailscale",   label: "TAIL", unit: "",                            tooltip: "Tailscale: Connected",  on: (tailscale-on?)}
    {name: "PIA VPN",     label: "PIA",  unit: "pia-vpn.service",             tooltip: "PIA VPN: Connected",    on: (active? "pia-vpn.service")}
    {name: "TU Wien VPN", label: "TU",   unit: "openconnect-tuwien.service",  tooltip: "TU Wien VPN: Connected", on: (active? "openconnect-tuwien.service")}
  ]
}

# Pushed after every toggle rather than waiting up to 15s for the poll.
# The popup's rows are a fixed tree in ironbar's config, so `entries` fills
# them through ironvars by position: `vpn_name_<n>` for the label, and
# `vpn_dot_<n>` for the state dot as Pango markup, filled and green while up,
# hollow and dim otherwise. `entries` probes every VPN, so it runs once here.
def refresh [] {
  let es = (entries)
  ^$BRIDGE push vpn (status-json $es)
  $es | enumerate | each {|e|
    let dot = if $e.item.on { $"<span foreground=\"($ON)\">●</span>" } else { $"<span foreground=\"($OFF)\">○</span>" }
    set-var $"vpn_name_($e.index)" $e.item.name
    set-var $"vpn_dot_($e.index)" $dot
  } | ignore
}

def status-json [es: list]: nothing -> string {
  let up = ($es | where on)
  if ($up | is-empty) {
    {text: " off", alt: "disconnected", tooltip: "No VPN active", class: "disconnected"}
  } else {
    {
      text: $" ($up | get label | str join '/')"
      alt: "connected"
      tooltip: ($up | get tooltip | str join "\n")
      class: "connected"
    }
  } | to json --raw
}

def main [] {
  print (status-json (entries))
}

# Menu contents for the dropdown.
def "main list" [] {
  print (entries | to json --raw)
}

def toggle-unit [unit: string, label: string, on: bool] {
  if $on {
    systemctl-user "stop" $unit
    notify $"($label) disconnected" "network-vpn-disconnected"
  } else {
    notify $"Connecting to ($label)..." "network-vpn"
    systemctl-user "start" $unit
    sleep 3sec
    if (active? $unit) {
      notify $"($label) connected" "network-vpn"
    } else {
      notify $"Failed to connect to ($label)" "dialog-error"
    }
  }
}

def "main toggle" [name: string] {
  let e = (entries | where name == $name | get 0?)
  if $e == null { return }

  if $e.unit == "" {
    if $e.on {
      ^$TAILSCALE down | complete | ignore
      notify "Tailscale disconnected" "network-vpn-disconnected"
    } else {
      ^$TAILSCALE up | complete | ignore
      notify "Tailscale connected" "network-vpn"
    }
  } else {
    toggle-unit $e.unit $e.name $e.on
  }

  refresh
}

# A popup row's click: rows know their position, not their name.
def "main toggle-row" [row: int] {
  let e = (entries | get -o $row)
  if $e != null { main toggle $e.name }
}

def "main disconnect-all" [] {
  mut any = false

  for e in (entries | where on) {
    $any = true
    if $e.unit == "" {
      ^$TAILSCALE down | complete | ignore
    } else {
      systemctl-user "stop" $e.unit
    }
  }

  if $any {
    notify "All VPNs disconnected" "network-vpn-disconnected"
  } else {
    notify "No VPN was active" "network-vpn"
  }

  refresh
}

# The bar polls through this rather than `bridge poll`, since a refresh
# carries the popup rows along with the record.
def "main push" [] { refresh }
