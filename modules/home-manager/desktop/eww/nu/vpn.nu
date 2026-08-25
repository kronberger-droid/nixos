#!@nu@/bin/nu -n

# VPN status, menu contents, and toggling. Merged from three waybar helpers:
# vpn-status.nu (unchanged logic), vpn-picker.nu (minus its rofi call) and
# vpn-disconnect-all.nu.
#
# The picker was rofi -dmenu over three fixed entries, which is a lot of
# machinery for a three-item list. It is now an eww dropdown that reads
# `vpn list` and calls `vpn toggle`, so the whole interaction stays in the
# widget layer and matches the bar's styling for free.
#
# One row per VPN rather than the bash version's two index-synced arrays, so
# filtering cannot misalign a label from its tooltip. The leading space in
# `text` is load-bearing for the bar's spacing.

def active? [unit: string] {
  (^@systemd@/bin/systemctl is-active $unit | complete).exit_code == 0
}

def notify [body: string, icon: string] {
  ^@libnotify@/bin/notify-send "VPN" $body -i $icon | complete | ignore
}

def systemctl-user [verb: string, unit: string] {
  ^/run/wrappers/bin/sudo /run/current-system/sw/bin/systemctl $verb $unit | complete | ignore
}

def tailscale-on? []: nothing -> bool {
  (^@tailscale@/bin/tailscale status | complete).exit_code == 0
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

# waybar refreshes on SIGRTMIN+8. eww has no signal mechanism, so the new state
# is pushed straight into the poll variable rather than waiting up to 15s.
def refresh [] {
  let dir = ($env.FILE_PWD | path dirname)
  ^@eww@/bin/eww -c $dir update $"vpn_state=(status-json)" | complete | ignore
  ^@eww@/bin/eww -c $dir update $"vpn_list=(entries | to json --raw)" | complete | ignore
}

def close-menu [] {
  let dir = ($env.FILE_PWD | path dirname)
  ^@eww@/bin/eww -c $dir close vpn-menu | complete | ignore
}

def status-json []: nothing -> string {
  let up = (entries | where on)
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
  print (status-json)
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

  close-menu

  if $e.unit == "" {
    if $e.on {
      ^@tailscale@/bin/tailscale down | complete | ignore
      notify "Tailscale disconnected" "network-vpn-disconnected"
    } else {
      ^@tailscale@/bin/tailscale up | complete | ignore
      notify "Tailscale connected" "network-vpn"
    }
  } else {
    toggle-unit $e.unit $e.name $e.on
  }

  refresh
}

def "main disconnect-all" [] {
  close-menu
  mut any = false

  for e in (entries | where on) {
    $any = true
    if $e.unit == "" {
      ^@tailscale@/bin/tailscale down | complete | ignore
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
