#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Hover-peek, click-pin drawers on ironvars.
#
# `show_if` takes a single `#var` and no expression, so `hover || pinned`
# cannot be written in the config. This owns the inputs and writes the
# result to `<name>_open`, which is what the drawer's children show on.
#
# Leaving is debounced. The handle and every child carry enter/leave hooks,
# and moving from one to the next fires a leave and an enter in either
# order. Each enter stamps `<name>_tok` with the time and the member's id;
# a leave waits DEBOUNCE, and clears hover unless an enter came after it,
# or within REVERSED before it from a different member. The id is
# what keeps a quick pass over one member (the narrow handle, say) from
# reading as a move into a sibling.
#
#   drawer (enter | leave) <name> <member>
#   drawer (pin | out) <name>

use "@barLib@" *

const MENUS = '@menuDrawers@'
const BAR_HEIGHT = "@barHeight@"

# Long enough to cross the gap between two members, short enough that
# leaving reads as immediate.
const DEBOUNCE = 150ms
# How far before a leave an enter may land and still count as crossing into
# a sibling: a reversed pair arrives within milliseconds of each other, a
# real hover-then-leave never does.
const REVERSED = 40ms

# How a menu drawer's leave is watched; see `leave`. MENU_REACH is how far
# from the tray, sideways and down, a menu can hang.
const WATCH_EVERY = 150ms
const WATCH_FOR = 2min
const MENU_REACH = {x: 220, y: 350}

# niri is called bare, as scratchpad.nu does: this only runs inside its
# session. Logical pixels, as the bar is laid out in.
def cursor []: nothing -> any {
  try { ^niri msg -j cursor-position | from json | select x y } catch { null }
}

# `known` holds the inputs this call has just written, so only the others are
# read back from the bar.
def refresh [name: string, known: record] {
  let open = ([hover pinned] | any {|k|
    if $k in $known { $known | get $k } else { (get-var $"($name)_($k)") == "true" }
  })
  set-var $"($name)_open" ($open | into string)
}

def "main enter" [name: string, member: string] {
  set-var $"($name)_tok" $"(date now | into int) ($member)"
  set-var $"($name)_hover" "true"
  # Hovered is open, whatever the other inputs say.
  set-var $"($name)_open" "true"
}

# Whether the pointer is back in the drawer since a leave from `member` at
# `start`; see the header.
def reentered [name: string, member: string, start: int]: nothing -> bool {
  let tok = (get-var $"($name)_tok" | split row " ")
  let at = (try { $tok | get 0 | into int } catch { 0 })
  let by = ($tok | get -o 1 | default "")
  ($at >= $start) or ($at >= ($start - ($REVERSED | into int)) and $by != $member)
}

def out-since [name: string, start: int]: nothing -> bool {
  (try { get-var $"($name)_out" | into int } catch { 0 }) >= ($start - ($REVERSED | into int))
}

def close [name: string] {
  set-var $"($name)_hover" "false"
  refresh $name {hover: false}
}

def "main leave" [name: string, member: string] {
  let start = (date now | into int)
  sleep $DEBOUNCE
  if (reentered $name $member $start) { return }
  if not ($name in ($MENUS | from json)) { close $name; return }

  # A tray icon's menu is a popover that grabs the pointer, so the bar reads
  # a leave the moment it opens, with the pointer still on the icon, and
  # again as the pointer moves down into it. Collapsing on either would take
  # the menu with it, and no single moment tells a menu from leaving. So
  # this watches until the pointer settles the question: back in the
  # drawer, it stays open; into a neighbour (`main out`), or off the bar and
  # well clear of where a menu hangs, it closes. Anything else, the pointer
  # on the icon or in the menu, keeps it open.
  let from = (cursor)
  let height = ($BAR_HEIGHT | into int)
  for _ in 1..($WATCH_FOR // $WATCH_EVERY) {
    if (reentered $name $member $start) { return }
    if (out-since $name $start) { close $name; return }
    let at = (cursor)
    if $at != null and $from != null and $at.y >= $height {
      if ($at.x - $from.x | math abs) > $MENU_REACH.x or $at.y > $MENU_REACH.y {
        close $name
        return
      }
    }
    sleep $WATCH_EVERY
  }
  close $name
}

def "main pin" [name: string] {
  let pinned = not ((get-var $"($name)_pinned") == "true")
  set-var $"($name)_pinned" ($pinned | into string)
  # The handle lights up while pinned.
  style (if $pinned { "add-class" } else { "remove-class" }) $"($name)-handle" pinned
  refresh $name {pinned: $pinned}
}

# The drawer's neighbours on the bar call this on entry; see `leave`.
def "main out" [name: string] {
  set-var $"($name)_out" (date now | into int | into string)
}

def main [] {
  print "usage: drawer (enter | leave) <name> <member>, drawer (pin | out) <name>"
}
