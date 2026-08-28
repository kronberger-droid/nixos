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

def sink-icon [v: int]: nothing -> string {
  let name = (sink-name)
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

def state-json []: nothing -> string {
  let sink = (vol-of $SINK)
  let src = (vol-of $SOURCE)
  let src_icon = if $src.muted { "" } else { "" }

  # vol and the glyph tail are separate fields: the widget pads the number
  # with dim leading zeroes, which it cannot do to a pre-formatted string.
  {
    vol: $sink.vol
    muted: $sink.muted
    suffix: (if $sink.muted {
      $" ($src_icon)"
    } else {
      $"% (sink-icon $sink.vol) ($src_icon)"
    })
    tooltip: $"(sink-name): ($sink.vol)%"
    class: (if $sink.muted { "muted" } else { "on" })
  } | to json --raw
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
# eww substituted into {}: "up" or "down", nothing else.
def "main scroll" [dir: string] {
  # eww only ever sends those two. Anything else is not ours to interpret,
  # and a bar handler has no stderr anyone would read, so bail silently.
  let step = match $dir {
    "up" => "1%+"
    "down" => "1%-"
    _ => { return }
  }
  # Unmute in both directions: scrolling a muted sink and hearing nothing is
  # the papercut this avoids. Before the volume change, so the push at the
  # bottom reads a sink that is already unmuted.
  ^$WPCTL set-mute $SINK 0 | complete | ignore

  # wpctl's relative form is VOL%[-/+]. -l takes a fraction, 1.0 being 100%,
  # and caps the result rather than the step, so it only bites on the way up.
  ^$WPCTL set-volume -l 1.0 $SINK $step | complete | ignore

  # Push rather than wait for the 2s poll, as toggle-mute does. `cfg`, not
  # `dir`: that name is the scroll direction here.
  let cfg = ($env.FILE_PWD | path dirname)
  ^$EWW -c $cfg update $"audio_state=(state-json)" | complete | ignore
}
