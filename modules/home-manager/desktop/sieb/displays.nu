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
# mode, and a different aspect ratio gets bars. Picking a side closes it,
# and so does either display going away: see `main mirror`.

const NOTIFY_SEND = "@libnotify@/bin/notify-send"
const PKILL       = "@procps@/bin/pkill"
const SETSID      = "@utilLinux@/bin/setsid"
const SIEB        = "@sieb@/bin/sieb"
const THEME       = "@theme@"
const WL_MIRROR   = "@wlMirror@/bin/wl-mirror"

const SELF  = path self
const SIDES = [Right Left Top Bottom]
const COPY  = "Duplicate"
# How often the copy checks that both displays are still there.
const POLL  = 2sec

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

# The outputs that are on, or null when niri does not answer.
def active-outputs []: nothing -> any {
  let asked = (^niri msg -j outputs | complete)
  if $asked.exit_code != 0 { return null }
  # An output that is off has no logical geometry.
  $asked.stdout | from json | values | where logical != null
}

# Runs the copy of `base` on `other` and closes it once either is gone.
#
# Left running after an unplug, the copy does harm: niri moves its window
# to the panel along with the rest of the workspace, where it shows the
# panel on the panel. That workspace then looks frozen and smears the
# cursor, since every frame it captures holds the one before.
def "main mirror" [other: string, base: string] {
  let mirror = (job spawn {
    ^$WL_MIRROR --fullscreen-output $other $base o+e> /dev/null
  })
  loop {
    sleep $POLL
    # Closed by hand, or by `stop-mirror` for a new pick.
    if (job list | where id == $mirror | is-empty) { return }
    let names = (active-outputs | default [] | get name)
    if $other not-in $names or $base not-in $names {
      job kill $mirror
      return
    }
  }
}

def main [] {
  let active = (active-outputs)
  if $active == null {
    notify "niri did not answer"
    exit 1
  }
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
    ^$SETSID -f $SELF mirror $other.name $base.name o+e> /dev/null
  } else if $picked in $SIDES {
    stop-mirror
    let to = (place $picked $base.logical $other.logical)
    move $base.name $to.base
    move $other.name $to.other
  }
}
