#!@nu@/bin/nu -n

# waybar's `network` module. Its config:
#   format-wifi         "{icon}"
#   format-ethernet     "{ifname} <eth glyph>"   (non-notebook)
#   format-disconnected <no-wifi glyph>
#   format-icons        five signal levels
#
# waybar picks the interface carrying the default route, so this does the same
# rather than guessing at names: this machine has enp86s0, wlo1, docker0 and
# tailscale0 up simultaneously, and only the routing table says which one the
# traffic is on.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const IP = "@iproute2@/bin/ip"

def default-iface []: nothing -> any {
  let route = (^$IP route show default | complete)
  if $route.exit_code != 0 { return null }
  let line = ($route.stdout | lines | get 0?)
  if $line == null { return null }
  let parts = ($line | split row " ")
  let i = ($parts | enumerate | where item == "dev" | get 0?.index)
  if $i == null { null } else { $parts | get ($i + 1) }
}

# /proc/net/wireless only lists wireless interfaces, so its presence is the
# test for "is this wifi", and its link column is the quality out of 70.
def wifi-quality [iface: string]: nothing -> any {
  let rows = (open --raw /proc/net/wireless | decode utf-8 | lines | skip 2)
  let hit = ($rows | where {|l| ($l | str trim | str starts-with $"($iface):") } | get 0?)
  if $hit == null { return null }
  let fields = ($hit | str trim | split row --regex '\s+')
  # "49." -> 49
  let link = ($fields | get 2? | default "0" | str replace "." "" | into int)
  [(($link * 100) // 70), 100] | math min
}

def ipaddr [iface: string]: nothing -> string {
  let out = (^$IP -4 -brief addr show dev $iface | complete)
  if $out.exit_code != 0 { return "" }
  ($out.stdout | split row --regex '\s+' | get 2? | default "" | split row "/" | get 0? | default "")
}

const ICONS = ["󰤯" "󰤟" "󰤢" "󰤥" "󰤨"]

def main [] {
  # `print`, not a bare pipeline: nushell only surfaces the *last* expression
  # of a block, so a value built before an early `return` is discarded. Two of
  # these three branches showed nothing at all until this was explicit.
  let iface = (default-iface)

  if $iface == null {
    print ({text: "󰖪", tooltip: "Disconnected", class: "disconnected"} | to json --raw)
    return
  }

  let q = (wifi-quality $iface)
  let ip = (ipaddr $iface)

  if $q == null {
    # Ethernet: waybar shows the interface name next to the glyph.
    print ({text: $"($iface) ", tooltip: $"($iface): ($ip)", class: "ethernet"} | to json --raw)
  } else {
    # waybar maps signal onto its icon list by proportion; five icons means
    # one per 20 points, clamped so 100 does not fall off the end.
    let idx = ([(($q * 5) // 100), 4] | math min)
    print ({text: ($ICONS | get $idx), tooltip: $"($iface): ($ip) \(($q)%\)", class: "wifi"} | to json --raw)
  }
}
