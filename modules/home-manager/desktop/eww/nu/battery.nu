#!@nu@/bin/nu -n

# waybar's `battery` module, read straight from /sys/class/power_supply. Its
# config:
#   interval         30
#   states           warning = 30, critical = 15
#   format           "{capacity}% {icon}"
#   format-charging  "{capacity}% <plug glyph>"
#   format-icons     ten glyphs, empty to full
#
# waybar kept this module off desktops with an `isNotebook` conditional in
# nix. The eww port cannot reuse that: the yuck files are copied verbatim, so
# no build-time flag reaches them. `present` replaces it, and the widget hides
# itself when it is false. One config for every host, and a machine that grows
# a battery gets the module without a rebuild.

# Empty to full, waybar's format-icons in order.
const ICONS = ["󱃍" "󰁺" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"]
const CHARGING = "󰂄"

const SYSFS = "/sys/class/power_supply"

# Every attribute is one short line, and half of them are optional: a full
# battery drops `current_now`, and only some firmware reports the `energy_*`
# pair at all. null rather than an error, so callers can `default` past a
# missing file.
def attr [dir: string, name: string]: nothing -> any {
  let f = ([$dir $name] | path join)
  if ($f | path exists) { open --raw $f | into string | str trim } else { null }
}

# Three filters, because three different things in this directory are not the
# battery we want.
#
# `type` drops the AC adapter and, on this machine, a USB-C source psy.
#
# `scope` drops a battery that powers a peripheral rather than the machine. A
# Logitech receiver registers its mouse as a `type = Battery` psy with
# `scope = Device`, which is what put a red 0% on a desktop bar. Real system
# batteries mostly omit the file rather than write "System", so a missing
# scope has to count as a system one.
#
# `capacity` drops a battery that reports no percentage. A psy is free to
# publish only the coarse `capacity_level` (Full/Good/Low/Critical), as that
# same mouse does, and the reading has to be absent rather than defaulted: 0
# is a plausible enough number to render as a real one.
def cells []: nothing -> list<record> {
  if not ($SYSFS | path exists) { return [] }
  ls $SYSFS
  | get name
  | where {|p| (attr $p "type") == "Battery" }
  | where {|p| (attr $p "scope" | default "System") == "System" }
  | where {|p| (attr $p "capacity") != null }
  | each {|p| {
      pct: (attr $p "capacity" | into int)
      status: (attr $p "status" | default "Unknown")
      # µAh/µA here, µWh/µW on firmware that reports watt-hours. now/rate is
      # hours in either unit system, so one path covers both.
      now: (attr $p "charge_now" | default (attr $p "energy_now") | default "0" | into int)
      full: (attr $p "charge_full" | default (attr $p "energy_full") | default "0" | into int)
      rate: (attr $p "current_now" | default (attr $p "power_now") | default "0" | into int)
    } }
}

def icon [pct: int, charging: bool]: nothing -> string {
  if $charging { return $CHARGING }
  # waybar spreads the icon list evenly over the range: 0-9 empty, 90+ full.
  $ICONS | get ([($pct / 10 | math floor) (($ICONS | length) - 1)] | math min)
}

# waybar's default tooltip is {timeTo}, which it derives the same way.
def time-left [c: record]: nothing -> string {
  if $c.rate == 0 { return "" }
  let remaining = if $c.status == "Charging" { $c.full - $c.now } else { $c.now }
  let hours = ($remaining / $c.rate)
  let h = ($hours | math floor)
  let m = ((($hours - $h) * 60) | math round)
  let tail = if $c.status == "Charging" { "to full" } else { "to empty" }
  $"($h) h ($m) min ($tail)"
}

def state-json []: nothing -> string {
  let cs = (cells)
  if ($cs | is-empty) {
    return ({present: false, pct: 0, suffix: "", tooltip: "", class: ""} | to json --raw)
  }

  # Averaged because waybar averages. Every host here has a single cell, so it
  # only ever matters on a two-battery machine.
  let pct = ($cs | get pct | math avg | math round | into int)
  let charging = ($cs | any {|c| $c.status == "Charging" })
  let first = ($cs | first)

  # pct and the glyph tail stay separate fields: the widget pads the number
  # with dim dashes, which it cannot do to a pre-formatted string.
  {
    present: true
    pct: $pct
    suffix: $"% (icon $pct $charging)"
    tooltip: ([$first.status $"($pct)%"]
              | append (let t = (time-left $first); if $t == "" { [] } else { [$t] })
              | str join ", ")
    # Charging does not clear these, matching waybar: its states and its
    # format-charging are independent.
    class: (if $pct <= 15 { "critical" } else if $pct <= 30 { "warning" } else { "" })
  } | to json --raw
}

def main [] {
  print (state-json)
}
