#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Where the external display sits, picked from a sieb prompt: right, left,
# above or below the laptop panel, centered on the edge they share, or a
# copy of it.
#
# For the display nobody wrote a shikane profile for, a projector say. It
# handles exactly two active outputs, since with three "the external one"
# is a question this menu does not ask.
#
# Positions go through `niri msg output`, which changes the running niri
# and no file: the next config reload or hotplug puts things back.
#
# niri has no mirroring, so the copy is wl-mirror showing the panel in a
# fullscreen window on the external display. That display keeps its own
# mode, and a different aspect ratio gets bars. Picking a side closes it.

const NOTIFY_SEND = "@libnotify@/bin/notify-send"
const PKILL       = "@procps@/bin/pkill"
const SETSID      = "@utilLinux@/bin/setsid"
const SIEB        = "@sieb@/bin/sieb"
const THEME       = "@theme@"
const WL_MIRROR   = "@wlMirror@/bin/wl-mirror"

const SIDES = [Right Left Top Bottom]
const COPY  = "Duplicate"

def notify [body: string] {
  ^$NOTIFY_SEND "Displays" $body | complete | ignore
}

# Where `base` and `other` go for `other` to sit on `side` of `base`,
# centered. Sizes and positions are logical pixels. Whichever ends up
# furthest left and furthest up is at 0, so nothing is negative: niri
# takes a negative position, its command line does not.
def place [side: string, base: record, other: record]: nothing -> record {
  let across = (($base.width - $other.width) / 2 | math round | into int)
  let down = (($base.height - $other.height) / 2 | math round | into int)
  let at = match $side {
    "Right" => {x: $base.width, y: $down}
    "Left" => {x: (0 - $other.width), y: $down}
    "Top" => {x: $across, y: (0 - $other.height)}
    "Bottom" => {x: $across, y: $base.height}
  }
  let left = ([0 $at.x] | math min)
  let top = ([0 $at.y] | math min)
  {
    base: {x: (0 - $left), y: (0 - $top)}
    other: {x: ($at.x - $left), y: ($at.y - $top)}
  }
}

def move [name: string, to: record] {
  let moved = (^niri msg output $name position set $to.x $to.y | complete)
  if $moved.exit_code != 0 {
    notify $"($name) did not move: ($moved.stderr | str trim)"
    exit 1
  }
}

def stop-mirror [] {
  ^$PKILL -x wl-mirror | complete | ignore
}

def main [] {
  let asked = (^niri msg -j outputs | complete)
  if $asked.exit_code != 0 {
    notify "niri did not answer"
    exit 1
  }
  # An output that is off has no logical geometry.
  let active = ($asked.stdout | from json | values | where logical != null)
  if ($active | length) != 2 {
    notify $"This needs two active displays, there are ($active | length)"
    return
  }

  # The laptop panel stays the reference whichever display has the focus.
  # Without one, on a desktop, the focused display is.
  let panels = ($active | where name =~ '^eDP')
  let base = if ($panels | length) == 1 {
    $panels | first
  } else {
    let focused = (^niri msg -j focused-output | complete | get stdout | from json)
    $active | where name == ($focused.name? | default "") | append $active | first
  }
  let other = ($active | where name != $base.name | first)

  let rows = ($SIDES | append $COPY)
  let picked = ($rows
    | str join "\n"
    | ^$SIEB --config $THEME -p $other.name --lines ($rows | length) --badge (char --unicode f108)
    | complete
    | get stdout
    | str trim)

  if $picked == $COPY {
    stop-mirror
    # Its own session, so it outlives this script.
    ^$SETSID -f $WL_MIRROR --fullscreen-output $other.name $base.name o+e> /dev/null
  } else if $picked in $SIDES {
    stop-mirror
    let to = (place $picked $base.logical $other.logical)
    move $base.name $to.base
    move $other.name $to.other
  }
}
