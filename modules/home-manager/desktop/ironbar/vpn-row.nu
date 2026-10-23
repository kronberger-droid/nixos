#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# The state dot of one VPN popup row, as eww's `.drop-row.on .dot`. Pango
# markup carries the colour, since custom widgets are a fixed tree that
# cannot loop over `vpn list` or swap classes per row the way eww's `for` did.

const VPN = "@vpn@"
const ON = "@on@"
const OFF = "@off@"

def main [name: string] {
  let row = (^$VPN list | from json | where name == $name | get 0?)
  let up = ($row.on? | default false)
  # Filled and green while up, hollow and dim otherwise, as eww's row has it.
  let dot = if $up { [$ON "●"] } else { [$OFF "○"] }
  print $"<span foreground=\"($dot.0)\">($dot.1)</span>"
}
