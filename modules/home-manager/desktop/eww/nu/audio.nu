#!@nu@/bin/nu -n

# waybar's `pulseaudio` module, on wpctl. Its config:
#   format               "{volume}% {icon} {format_source}"
#   format-muted         "<muted glyph> {format_source}"
#   format-icons default three levels, headphones/headset/handsfree one glyph
#   format-source        mic on / mic muted
#
# waybar picks the icon from the sink's *port type*, which PipeWire does not
# expose through wpctl. The node name does though: a bluetooth sink is
# bluez_output.*, which is what "headphones" means in practice on this machine.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const EWW   = "@eww@/bin/eww"
const WPCTL = "@wireplumber@/bin/wpctl"
const FLOCK = "@utilLinux@/bin/flock"
const NU    = "@nu@/bin/nu"

# wpctl's own identifiers happen to look like replaceVars placeholders, and
# replaceVars fails the build on any placeholder it was not given a value for.
# Built by concatenation so the literal pattern never appears here.
const SINK = ("@" + "DEFAULT_AUDIO_SINK" + "@")
const SOURCE = ("@" + "DEFAULT_AUDIO_SOURCE" + "@")

def vol-of [target: string]: nothing -> record {
  let out = (^$WPCTL get-volume $target | complete)
  if $out.exit_code != 0 { return {vol: 0, muted: true} }
  let t = ($out.stdout | str trim)
  {
    # "Volume: 0.26" or "Volume: 0.26 [MUTED]"
    vol: (($t | split row " " | get 1? | default "0" | into float) * 100 | math round)
    muted: ($t | str contains "MUTED")
  }
}

def sink-name []: nothing -> string {
  let out = (^$WPCTL inspect $SINK | complete)
  if $out.exit_code != 0 { return "" }
  ($out.stdout
   | lines
   | where {|l| $l | str contains "node.name" }
   | get 0?
   | default ""
   | split row "="
   | get 1?
   | default ""
   | str trim
   | str trim --char '"')
}

def sink-icon [name: string, v: int]: nothing -> string {
  if (($name | str contains "bluez") or ($name | str contains "headset")) {
    ""
  } else if $v <= 33 {
    ""
  } else if $v <= 66 {
    ""
  } else {
    ""
  }
}

# Pure, so the scroll handler can rebuild the state without gathering all of
# it again. `name` and `src_muted` ride along in the JSON for that reason: the
# widget hands them back as scroll arguments.
def render [name: string, sink: record, src_muted: bool]: nothing -> string {
  let src_icon = if $src_muted { "" } else { "" }

  # vol and the glyph tail are separate fields: the widget pads the number
  # with dim dashes, which it cannot do to a pre-formatted string.
  {
    vol: $sink.vol
    muted: $sink.muted
    suffix: (if $sink.muted {
      $" ($src_icon)"
    } else {
      $"% (sink-icon $name $sink.vol) ($src_icon)"
    })
    tooltip: $"($name): ($sink.vol)%"
    class: (if $sink.muted { "muted" } else { "on" })
    name: $name
    src_muted: $src_muted
  } | to json --raw
}

def state-json []: nothing -> string {
  render (sink-name) (vol-of $SINK) (vol-of $SOURCE).muted
}

def main [] {
  print (state-json)
}

# waybar's on-click opens wiremix; its scroll-to-change-volume is `main
# scroll` below.
def "main toggle-mute" [] {
  ^$WPCTL set-mute $SINK toggle | complete | ignore
  # Push rather than wait for the 2s poll, as the other toggles do.
  let dir = ($env.FILE_PWD | path dirname)
  ^$EWW -c $dir update $"audio_state=(state-json)" | complete | ignore
}

# The bar's scroll handler, waybar's scroll-to-change-volume. `dir` is what
# eww substituted into {}: "up" or "down", nothing else. `name` and
# `src_muted` are the widget's current audio_state handed back, neither of
# which a scroll changes.
#
# eww runs one handler per GTK scroll event and passes only the sign, never
# the amount. A hi-res wheel sends a notch as a burst of small events (the
# M705 here: 8, about 8ms apart, so ~70ms a notch) and a touchpad sends a
# stream, so stepping once per event made a notch 8%. Without the amount,
# time is the only thing left to go by: the first event of a burst takes a
# step and holds the lock for THROTTLE, and every event that finds it held
# is dropped. A notch on any wheel is then one step, a fast spin still gives
# one step per notch up to 10 a second, and a touchpad swipe scrolls at a
# steady rate. Holding the lock also keeps two steps from ever overlapping,
# which matters since `wpctl set-volume 1%-` reads the volume and writes it
# back, and overlapping calls collapsed into one step.
const THROTTLE = 100ms

def "main scroll" [dir: string, name: string, src_muted: bool] {
  # eww only ever sends those two. Anything else is not ours to interpret,
  # and a bar handler has no stderr anyone would read, so bail silently.
  let step = match $dir {
    "up" => "1%+"
    "down" => "1%-"
    _ => { return }
  }
  let lock = ($env.XDG_RUNTIME_DIR? | default "/tmp" | path join "eww-audio-scroll.lock")
  # -n fails at once rather than queueing; that failure is the drop.
  (^$FLOCK -n $lock $NU -n $env.CURRENT_FILE scroll-locked $step $name
    ($src_muted | into string)) | complete | ignore
}

# The body `main scroll` runs under the lock. Kept to two wpctl calls on an
# ordinary tick: every wpctl call opens its own PipeWire connection, and the
# full state-json here took a step to 100-130ms, more than THROTTLE itself.
def "main scroll-locked" [step: string, name: string, src_muted: bool] {
  let start = (date now)

  # wpctl's relative form is VOL%[-/+]. -l takes a fraction, 1.0 being 100%,
  # and caps the result rather than the step, so it only bites on the way up.
  ^$WPCTL set-volume -l 1.0 $SINK $step | complete | ignore

  # Unmute in both directions: scrolling a muted sink and hearing nothing is
  # the papercut this avoids. Only when the read says muted, which spares a
  # call on every ordinary tick.
  let sink = (vol-of $SINK)
  let sink = if $sink.muted {
    ^$WPCTL set-mute $SINK 0 | complete | ignore
    $sink | update muted false
  } else { $sink }

  # Push rather than wait for the 2s poll, as toggle-mute does. `cfg`, not
  # `dir`: that name is the scroll direction here.
  let cfg = ($env.FILE_PWD | path dirname)
  let state = (render $name $sink $src_muted)
  ^$EWW -c $cfg update $"audio_state=($state)" | complete | ignore

  # Hold the lock out to THROTTLE; the rest of this burst lands on it.
  let left = ($THROTTLE - ((date now) - $start))
  if $left > 0sec { sleep $left }
}
