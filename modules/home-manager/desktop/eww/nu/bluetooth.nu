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

def powered? []: nothing -> bool {
  let out = (^@systemd@/bin/busctl --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered | complete)
  ($out.stdout | str trim) == "b true"
}

# "Device CC:98:8B:3D:E3:99 WH-1000XM3" -> {mac, alias}
def connected []: nothing -> list {
  let out = (^@bluez@/bin/bluetoothctl devices Connected | complete)
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
  let out = (^@bluez@/bin/bluetoothctl info $mac | complete)
  if $out.exit_code != 0 { return null }
  let line = ($out.stdout | lines | where {|l| $l | str contains "Battery Percentage" } | get 0?)
  if $line == null { return null }
  let m = ($line | parse --regex '\((?<pct>\d+)\)' | get 0?)
  if $m == null { null } else { $m.pct | into int }
}

def main [] {
  # `print`, not a bare pipeline: nushell only surfaces the *last* expression
  # of a block, so a value built before an early `return` is discarded. Two of
  # these three branches showed nothing at all until this was explicit.
  if (not (powered?)) {
    print ({text: "󰂲 off", tooltip: "Bluetooth off", class: "off"} | to json --raw)
    return
  }

  let devs = (connected)

  if ($devs | is-empty) {
    print ({text: "󰂯 on", tooltip: "Bluetooth on, nothing connected", class: "on"} | to json --raw)
    return
  }

  let d = ($devs | get 0)
  let batt = (battery $d.mac)
  let text = if $batt == null {
    $"󰂱 ($d.alias)"
  } else {
    $"󰂱 ($d.alias) ($batt)%"
  }

  {
    text: $text
    # waybar's tooltip enumerates every connected device with its address.
    tooltip: ($devs | each {|x| $"($x.alias)\t($x.mac)" } | str join "\n")
    class: "connected"
  } | to json --raw | print
}

# waybar's on-click-right toggles power through D-Bus, for the reason above.
def "main toggle" [] {
  if (powered?) {
    ^@bluez@/bin/bluetoothctl power off | complete | ignore
  } else {
    ^@bluez@/bin/bluetoothctl power on | complete | ignore
  }
}
