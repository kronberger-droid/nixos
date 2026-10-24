#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Hover-peek, click-pin drawers on ironvars.
#
# `show_if` takes a single `#var` and no expression, so `hover || pinned`
# cannot be written in the config. This owns the inputs and writes the
# result to `<name>_open`, which is what the drawer's children show on.
#
# Leaving is debounced. The handle and every child carry enter/leave hooks,
# and moving from one to the next fires the old one's leave before the new
# one's enter. Each enter stamps `<name>_tok`; a leave waits, and only clears
# hover if no enter has stamped since.
#
#   drawer (enter | leave | pin) <name>
#   drawer busy <name> (true | false)

use "@barLib@" *

# `known` holds the inputs this call has just written, so only the others are
# read back from the bar.
def refresh [name: string, known: record] {
  let open = ([hover pinned busy] | any {|k|
    if $k in $known { $known | get $k } else { (get-var $"($name)_($k)") == "true" }
  })
  set-var $"($name)_open" ($open | into string)
}

def "main enter" [name: string] {
  set-var $"($name)_tok" (date now | format date "%s%f")
  set-var $"($name)_hover" "true"
  # Hovered is open, whatever the other inputs say.
  set-var $"($name)_open" "true"
}

def "main leave" [name: string] {
  let tok = (get-var $"($name)_tok")
  sleep 50ms
  if (get-var $"($name)_tok") == $tok {
    set-var $"($name)_hover" "false"
    refresh $name {hover: false}
  }
}

def "main pin" [name: string] {
  let pinned = not ((get-var $"($name)_pinned") == "true")
  set-var $"($name)_pinned" ($pinned | into string)
  # The handle lights up while pinned.
  style (if $pinned { "add-class" } else { "remove-class" }) $"($name)-handle" pinned
  refresh $name {pinned: $pinned}
}

# Held up from outside the hover: audio.nu raises it through a slider drag,
# which can leave the bar without collapsing the slider under the pointer.
def "main busy" [name: string, on: bool] {
  set-var $"($name)_busy" ($on | into string)
  refresh $name {busy: $on}
}

def main [] {
  print "usage: drawer (enter | leave | pin) <name>, drawer busy <name> <on>"
}
