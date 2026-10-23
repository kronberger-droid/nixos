#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# waybar's `pulseaudio` module, on wpctl. Its config:
#   format               "{volume}% {icon} {format_source}"
#   format-muted         "<muted glyph> {format_source}"
#   format-icons default three levels, headphones/headset/handsfree one glyph
#   format-source        mic on / mic muted
#
# waybar picks the icon from the sink's *port type*, which PipeWire does not
# expose through wpctl. The node name does though: a bluetooth sink is
# bluez_output.*, which is what "headphones" means in practice on this machine.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const BRIDGE = "@bridge@"
const DRAWER = "@drawer@"
const WPCTL = "@wireplumber@/bin/wpctl"
const FLOCK = "@utilLinux@/bin/flock"
const NU    = "@nu@/bin/nu"

# `detach`, for the slider's linger below.
use "@barLib@" *

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
# scroll` below, and the hover slider waybar never had is `main set`.
def "main toggle-mute" [] {
  ^$WPCTL set-mute $SINK toggle | complete | ignore
  # Push rather than wait for the 2s poll, as the other toggles do.
  ^$BRIDGE push audio (state-json)
}

# The bar polls through this.
def "main push" [] { ^$BRIDGE push audio (state-json) }

# The bar's scroll handler, waybar's scroll-to-change-volume. `dir` is "up"
# or "down", nothing else. `name` and `src_muted` are the current state
# handed back, neither of which a scroll changes; eww passed them, ironbar
# cannot, and without them settle queries the full state instead.
#
# The bar runs one handler per GTK scroll event and passes only the sign, never
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

def "main scroll" [dir: string, name: string = "", src_muted: bool = false] {
  # The bar only ever sends those two. Anything else is not ours to interpret,
  # and a bar handler has no stderr anyone would read, so bail silently.
  let step = match $dir {
    "up" => "2%+"
    "down" => "2%-"
    _ => { return }
  }
  let lock = ($env.XDG_RUNTIME_DIR? | default "/tmp" | path join "bar-audio-scroll.lock")
  # -n fails at once rather than queueing; that failure is the drop.
  (^$FLOCK -n $lock $NU -n --no-std-lib $env.CURRENT_FILE scroll-locked $step $name
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
  settle $name $src_muted

  # Hold the lock out to THROTTLE; the rest of this burst lands on it.
  let left = ($THROTTLE - ((date now) - $start))
  if $left > 0sec { sleep $left }
}

# The tail every volume change shares, after the new volume is written.
def settle [name: string, src_muted: bool] {
  # Unmute in both directions: changing a muted sink and hearing nothing is
  # the papercut this avoids. Only when the read says muted, which spares a
  # call on every ordinary tick.
  let sink = (vol-of $SINK)
  let sink = if $sink.muted {
    ^$WPCTL set-mute $SINK 0 | complete | ignore
    $sink | update muted false
  } else { $sink }

  # Push rather than wait for the 2s poll, as toggle-mute does. Without the
  # handed-back name there is nothing to render from, so gather it all.
  let state = if ($name | is-empty) { state-json } else { render $name $sink $src_muted }
  ^$BRIDGE push audio $state
}

# The hover slider's on_change. `value` is the slider position, an absolute
# percentage; `name` and `src_muted` are optional as they are for scroll.
#
# A drag fires once per whole percent it crosses, so this sees the same kind
# of burst scroll does, but scroll's drop-the-losers throttle is wrong here.
# Scroll steps are relative and any one of them will do; a slider position is
# absolute and the one that matters is the last, which is exactly the one most
# likely to land on a held lock and be dropped. So the last value wins
# instead: every call parks its value in TARGET, then queues on the lock, and
# whoever holds it applies whatever TARGET says at that moment and consumes
# it. Since each call writes before it queues, the final position is always
# read by some later holder; the calls behind it find TARGET gone and exit.
#
# The write is a rename so a holder never reads a half-written file, or
# unlinks one that is still being written and loses the value with it.
def "main set" [value: float, name: string = "", src_muted: bool = false] {
  let run = ($env.XDG_RUNTIME_DIR? | default "/tmp")
  hold $run

  let target = ($run | path join "bar-audio-set.target")
  let tmp = $"($target).($nu.pid)"
  $value | math round | into string | save -f $tmp
  mv -f $tmp $target
  # Blocking, unlike scroll's -n: queueing is the point.
  (^$FLOCK ($run | path join "bar-audio-set.lock")
    $NU -n --no-std-lib $env.CURRENT_FILE set-locked $name ($src_muted | into string))
  | complete | ignore
}

def "main set-locked" [name: string, src_muted: bool] {
  let target = ($env.XDG_RUNTIME_DIR? | default "/tmp" | path join "bar-audio-set.target")
  if not ($target | path exists) { return }
  let pct = (try { open --raw $target | into string | str trim | into int } catch { null })
  rm -f $target
  if $pct == null { return }

  ^$WPCTL set-volume $SINK $"($pct)%" | complete | ignore
  settle $name $src_muted
}

# Keeps the slider out while it is being dragged. Dragging off the bar is a
# hover-lost like any other, and the bar's leave hook carries neither the
# button state nor the crossing mode. A recent slider change is the only sign
# of a drag left, so every set holds the audio drawer's busy flag up for
# LINGER past itself, which drawer.nu ORs into `audio_open`. Holding the pointer still off the bar for longer than that
# still collapses it.
#
# Each set writes its own token to STAMP and leaves a detached linger behind
# it; a linger clears the flag only if STAMP still holds its token when it
# wakes, so only the last set of a drag clears it. Lockless on purpose: a
# single worker that loops until things go quiet can decide to exit just as
# another set arrives, and then nothing ever clears the flag. The token goes
# in before the flag goes up, which keeps a linger that is just waking from
# clearing a flag this set has only now raised.
const LINGER = 800ms

def hold [run: string] {
  let stamp = ($run | path join "bar-audio-set.stamp")
  let tok = (date now | into int | into string)
  let tmp = $"($stamp).($nu.pid)"
  $tok | save -f $tmp
  mv -f $tmp $stamp

  ^$DRAWER busy audio true
  detach ...[$NU "-n" "--no-std-lib" $env.CURRENT_FILE "linger" $tok]
}

def "main linger" [tok: string] {
  sleep $LINGER
  let stamp = ($env.XDG_RUNTIME_DIR? | default "/tmp" | path join "bar-audio-set.stamp")
  let now = (try { open --raw $stamp | into string | str trim } catch { "" })
  if $now != $tok { return }
  ^$DRAWER busy audio false
}
