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

# wpctl's own identifiers happen to look like replaceVars placeholders, and
# replaceVars fails the build on any placeholder it was not given a value for.
# Built by concatenation so the literal pattern never appears here.
const SINK = ("@" + "DEFAULT_AUDIO_SINK" + "@")
const SOURCE = ("@" + "DEFAULT_AUDIO_SOURCE" + "@")

def vol-of [target: string]: nothing -> record {
  let out = (^@wireplumber@/bin/wpctl get-volume $target | complete)
  if $out.exit_code != 0 { return {vol: 0, muted: true} }
  let t = ($out.stdout | str trim)
  {
    # "Volume: 0.26" or "Volume: 0.26 [MUTED]"
    vol: (($t | split row " " | get 1? | default "0" | into float) * 100 | math round)
    muted: ($t | str contains "MUTED")
  }
}

def sink-name []: nothing -> string {
  let out = (^@wireplumber@/bin/wpctl inspect $SINK | complete)
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

def main [] {
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

# waybar's on-click opens wiremix; scroll is not ported because eww has no
# scroll event on a widget.
def "main toggle-mute" [] {
  ^@wireplumber@/bin/wpctl set-mute $SINK toggle | complete | ignore
}
