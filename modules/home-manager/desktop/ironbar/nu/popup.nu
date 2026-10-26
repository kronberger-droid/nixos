#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Closes a module's popup once the pointer has left it alone.
#
# ironbar closes a popup only on a click, and the built-ins open theirs from
# the button's own click handler, out of reach of the config. The popup is a
# surface of its own with no hooks, so where the pointer is comes from niri.
# A leave from a popup module watches until the popup is gone, the pointer is
# back on a popup module (whose own leave then takes over), or it has spent
# AWAY outside the area a popup hangs in, and then hides the popup.
#
#   popup (enter | leave)

use "@barLib@" *

const IRONBAR = "@ironbar@/bin/ironbar"
const BAR = "@barName@"
const BAR_HEIGHT = "@barHeight@"

const WATCH_EVERY = 150ms
const AWAY = 1sec
# How far from the leave point, sideways and down, a popup can hang. The
# volume popup is the big one, and one at the screen's edge is pushed in.
const REACH = {x: 300, y: 500}

# As in drawer.nu: niri is called bare, logical pixels.
def cursor []: nothing -> any {
  try { ^niri msg -j cursor-position | from json | select x y } catch { null }
}

# Every bar shares BAR, so with several outputs this reads true if any is open.
def visible []: nothing -> bool {
  (^$IRONBAR bar $BAR get-popup-visible | complete).stdout | str contains "true"
}

def "main enter" [] {
  set-var popup_tok (date now | into int | into string)
}

def "main leave" [] {
  let start = (date now | into int)
  let from = (cursor)
  let height = ($BAR_HEIGHT | into int)
  # When the pointer went out, in ns since the epoch; 0 while it is inside.
  mut away_since = 0

  loop {
    if (try { get-var popup_tok | into int } catch { 0 }) >= $start { return }
    if not (visible) { return }

    let at = (cursor)
    # Off the bar and near where it was left is in the popup, or on the way.
    # On the bar is on some other module. An unknown position keeps it open.
    let inside = if $at == null or $from == null {
      true
    } else {
      $at.y >= $height and ($at.x - $from.x | math abs) <= $REACH.x and $at.y <= $REACH.y
    }

    let now = (date now | into int)
    if $inside {
      $away_since = 0
    } else if $away_since == 0 {
      $away_since = $now
    } else if ($now - $away_since) >= ($AWAY | into int) {
      ^$IRONBAR bar $BAR hide-popup | complete | ignore
      return
    }
    sleep $WATCH_EVERY
  }
}

def main [] {
  print "usage: popup (enter | leave)"
}
