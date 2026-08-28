#!@nu@/bin/nu -n

# waybar's `bluetooth` module. Its config:
#   format                      "<bt> on"
#   format-off / -disabled      "<bt-off> off"
#   format-connected            "<bt-connected> {device_alias}"
#   format-connected-battery    "<bt-connected> {device_alias} {battery}%"
#
# Power state comes from D-Bus, not `bluetoothctl show`. waybar.nix carries the
# same note: BlueZ 5.86 changed `show`'s output so the old grep never matched
# and the toggle only ever powered on. `bluetoothctl` is still fine for reading
# the device list and battery level, which have not moved.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const BLUETOOTHCTL = "@bluez@/bin/bluetoothctl"
const BUSCTL       = "@systemd@/bin/busctl"
const EWW          = "@eww@/bin/eww"

def powered? []: nothing -> bool {
  let out = (^$BUSCTL --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered | complete)
  ($out.stdout | str trim) == "b true"
}

# "Device CC:98:8B:3D:E3:99 WH-1000XM3" -> {mac, alias}
def connected []: nothing -> list {
  let out = (^$BLUETOOTHCTL devices Connected | complete)
  if $out.exit_code != 0 { return [] }
  $out.stdout
  | lines
  | where {|l| $l | str starts-with "Device " }
  | each {|l|
      let parts = ($l | split row " ")
      {mac: ($parts | get 1), alias: ($parts | skip 2 | str join " ")}
    }
}

# "Battery Percentage: 0x46 (70)" -> 70
def battery [mac: string]: nothing -> any {
  let out = (^$BLUETOOTHCTL info $mac | complete)
  if $out.exit_code != 0 { return null }
  let line = ($out.stdout | lines | where {|l| $l | str contains "Battery Percentage" } | get 0?)
  if $line == null { return null }
  let m = ($line | parse --regex '\((?<pct>\d+)\)' | get 0?)
  if $m == null { null } else { $m.pct | into int }
}

# waybar refreshed on a signal; eww has none, so the new state is pushed
# straight into the poll variable. Without this the 5s interval makes a
# right-click look like it did nothing, which is what it looked like.
#
# BlueZ settles the Powered property a moment after bluetoothctl returns, so
# this waits for the value to actually change rather than reading it back
# immediately and pushing the old one.
def refresh [] {
  let dir = ($env.FILE_PWD | path dirname)
  ^$EWW -c $dir update $"bt_state=(status-json)" | complete | ignore
}

def status-json []: nothing -> string {
  if (not (powered?)) {
    return ({text: "\u{f00b2} off", tooltip: "Bluetooth off", class: "off"} | to json --raw)
  }

  let devs = (connected)

  if ($devs | is-empty) {
    return ({text: "\u{f00af} on", tooltip: "Bluetooth on, nothing connected", class: "on"} | to json --raw)
  }

  let d = ($devs | get 0)
  let batt = (battery $d.mac)
  let text = if $batt == null {
    $"\u{f00b1} ($d.alias)"
  } else {
    $"\u{f00b1} ($d.alias) ($batt)%"
  }

  {
    text: $text
    # waybar's tooltip enumerates every connected device with its address.
    tooltip: ($devs | each {|x| $"($x.alias)\t($x.mac)" } | str join "\n")
    class: "connected"
  } | to json --raw
}

def main [] {
  print (status-json)
}

def "main toggle" [] {
  let was = (powered?)
  if $was {
    ^$BLUETOOTHCTL power off | complete | ignore
  } else {
    ^$BLUETOOTHCTL power on | complete | ignore
  }

  for _ in 1..20 {
    if (powered?) != $was { break }
    sleep 50ms
  }
  refresh
}
