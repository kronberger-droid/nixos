#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Hover-peek, click-pin drawers, the eww clusters' behaviour on ironvars.
#
# `show_if` takes a single `#var` and no expression, so `hover || pinned`
# cannot be written in the config. This owns the three inputs and writes the
# result to `<name>_open`, which is what the drawer's children show on.
#
# Leaving is debounced. The handle and every child carry enter/leave hooks,
# and moving from one to the next fires the old one's leave before the new
# one's enter. Each enter stamps `<name>_tok`; a leave waits, and only clears
# hover if no enter has stamped since. The same race eww's clusters hit, from
# the other side: there GTK dropped the leave, here it arrives too early.
#
#   drawer (enter | leave | pin) <name>

const IRONBAR = "@ironbar@/bin/ironbar"

def get-var [key: string]: nothing -> string {
  let r = (^$IRONBAR var get $key | complete)
  if $r.exit_code == 0 { $r.stdout | str trim } else { "" }
}

def set-var [key: string, value: string] {
  ^$IRONBAR var set $key $value | complete | ignore
}

def refresh [name: string] {
  let open = ((get-var $"($name)_hover") == "true") or ((get-var $"($name)_pinned") == "true")
  set-var $"($name)_open" ($open | into string)
}

def "main enter" [name: string] {
  set-var $"($name)_tok" (date now | format date "%s%f")
  set-var $"($name)_hover" "true"
  refresh $name
}

def "main leave" [name: string] {
  let tok = (get-var $"($name)_tok")
  sleep 50ms
  if (get-var $"($name)_tok") == $tok {
    set-var $"($name)_hover" "false"
    refresh $name
  }
}

def "main pin" [name: string] {
  let pinned = (get-var $"($name)_pinned") == "true"
  set-var $"($name)_pinned" (not $pinned | into string)
  # The handle lights up while pinned, as eww's `.cluster.pinned .handle`.
  let op = if $pinned { "remove-class" } else { "add-class" }
  ^$IRONBAR style $op $"($name)-handle" pinned | complete | ignore
  refresh $name
}

def main [] {
  print "usage: drawer (enter | leave | pin) <name>"
}
