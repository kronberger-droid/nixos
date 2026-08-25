#!@nu@/bin/nu -n

# waybar's custom/mpris, reimplemented on playerctl.
#
# waybar runs `waybar-mpris --order SYMBOL:PLAYER --separator '' --autofocus
# --pause <glyph> --play <glyph>` piped through `sd` to rename chromium/chrome
# to Brave. That binary is a singleton with an IPC socket (which is what its
# `--send toggle` talks to), so a second instance produces nothing while waybar
# holds the first. playerctl has no such constraint, which is what lets this be
# developed and tested with waybar still running.
#
# `--follow` blocks and waits even when no player exists, so this stays alive
# and starts emitting when one appears; exactly what deflisten wants.

def render [line: string]: nothing -> string {
  let parts = ($line | split row "|")
  let status = ($parts | get 0? | default "" | str trim)
  let player = ($parts | get 1? | default "" | str trim)

  if ($player | is-empty) {
    return ({text: "", tooltip: "", class: "none"} | to json --raw)
  }

  # waybar pipes through `sd '[Cc]hromium|chrome' 'Brave'`; nushell's own
  # replace does it without the extra dependency, as the nu ports in
  # waybar/nu/ already do elsewhere.
  let name = ($player | str replace --all --regex '[Cc]hromium|chrome' 'Brave')

  # waybar-mpris shows --play while playing and --pause otherwise.
  let symbol = if $status == "Playing" { "" } else { "" }

  {
    text: $"($symbol) ($name)"
    tooltip: $"($name): ($status)"
    class: ($status | str lowercase)
  } | to json --raw
}

def main [] {
  ^@playerctl@/bin/playerctl -f '{{status}}|{{playerName}}' metadata --follow
  | lines
  | each {|line| print (render $line) }
  | ignore
}

# waybar: on-click = --send toggle.
def "main toggle" [] {
  ^@playerctl@/bin/playerctl play-pause | complete | ignore
}

# waybar: on-click-right = --send player-next, which cycles between *players*.
# playerctl has no direct equivalent, and skipping the track is the more useful
# binding on a right-click, so this deviates deliberately.
def "main next" [] {
  ^@playerctl@/bin/playerctl next | complete | ignore
}
