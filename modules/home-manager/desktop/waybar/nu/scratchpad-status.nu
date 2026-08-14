#!@nu@/bin/nu -n

# niri is called bare rather than by store path, as in the bash version:
# waybar only ever runs inside the niri session.
let windows = (^niri msg -j windows | complete)
let open = (if $windows.exit_code == 0 {
  $windows.stdout | from json | any {|w| $w.app_id? == "scratchpad"}
} else {
  false
})

if $open {
  {text: "\u{f489}", alt: "open", tooltip: "Scratchpad open", class: "open"}
} else {
  {text: "\u{f489}", alt: "closed", tooltip: "Scratchpad closed", class: "closed"}
} | to json --raw
