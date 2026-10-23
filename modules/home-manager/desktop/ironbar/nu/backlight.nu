#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# waybar's `backlight` module, on brightnessctl. Its config:
#   format         "{percent}% {icon}"
#   format-icons   three glyphs, dim to bright
#   on-scroll-up   brightnessctl set +50
#   on-scroll-down brightnessctl set 50-
#
# Same story as battery.nu: waybar gated this on `isNotebook` in nix, and the
# yuck files see no build-time flags, so absence is detected here instead and
# the widget hides itself.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const BRIDGE = "@bridge@"
const BRIGHTNESSCTL = "@brightnessctl@/bin/brightnessctl"

# Dim to bright, waybar's format-icons in order.
const ICONS = ["󰃞" "󰃟" "󰃠"]

# -m is brightnessctl's machine-readable form, one comma-separated line:
#   intel_backlight,backlight,18850,20%,96000
# -c pins the class, as niri.nix's brightness keybinds do, so a keyboard
# backlight cannot end up answering for the screen.
def percent []: nothing -> any {
  let out = (^$BRIGHTNESSCTL -m -c backlight | complete)
  if $out.exit_code != 0 { return null }
  let line = ($out.stdout | lines | get 0? | default "")
  if ($line | is-empty) { return null }
  $line | split row "," | get 3? | default "0%" | str trim --char '%' | into int
}

def state-json []: nothing -> string {
  let p = (percent)
  if $p == null {
    return ({present: false, pct: 0, suffix: "", tooltip: "", class: ""} | to json --raw)
  }
  {
    present: true
    pct: $p
    # Separate fields, so the widget can pad the number; see audio.nu.
    suffix: $"% ($ICONS | get ([($p * ($ICONS | length) / 100 | math floor) (($ICONS | length) - 1)] | math min))"
    tooltip: $"Backlight: ($p)%"
    class: ""
  } | to json --raw
}

def main [] {
  print (state-json)
}

# The bar's scroll handler. `dir` is "up" or "down", nothing else.
def "main scroll" [dir: string] {
  # 5%, not waybar's literal `set +50`. That 50 is raw units, and this panel
  # reports a max of 96000, so a notch moved the backlight by 0.05% and read
  # as a dead scroll wheel. Percent also keeps the step even across panels,
  # whose ranges differ by orders of magnitude.
  let step = match $dir {
    "up" => "+5%"
    "down" => "5%-"
    # The bar only ever sends those two. Anything else is not ours to interpret,
    # and a bar handler has no stderr anyone would read, so bail silently.
    _ => { return }
  }
  ^$BRIGHTNESSCTL -c backlight set $step | complete | ignore

  # Push rather than wait for the poll, as the audio scroll handler does.
  refresh
}

def refresh [] {
  ^$BRIDGE push backlight (state-json)
}

# The bar polls through this; toggles push the same way after they act.
def "main push" [] { refresh }
