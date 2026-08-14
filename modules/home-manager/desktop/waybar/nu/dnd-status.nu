#!@nu@/bin/nu -n

# makoctl prints one active mode per line.
let on = ((^@mako@/bin/makoctl mode | complete).stdout
  | lines
  | any {|m| $m == "do-not-disturb"})

if $on {
  {text: "\u{f1f6}", alt: "on", tooltip: "Do Not Disturb: ON", class: "on"}
} else {
  {text: "\u{f0f3}", alt: "off", tooltip: "Do Not Disturb: OFF", class: "off"}
} | to json --raw
