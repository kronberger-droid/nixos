#!@nu@/bin/nu -n

# waybar.nix's `tui` attrset and `dropkittenCmd`, in one script.
#
# Five modules open a TUI in a dropdown terminal: network -> nmtui, pulseaudio
# -> wiremix, bluetooth -> bluetuith, clock -> calcurse, cpu -> btop. In
# waybar.nix that is a Nix function applied five times; here it is one script
# with a subcommand, so the widgets just call `scripts/tui wifi`.
#
# btop is deliberately not routed through dropkitten: waybar.nix notes that
# btop needs at least 80x24 and dropkitten's fractional sizing came up short,
# so niri's btop_monitor window rule sizes it instead.

const NMTUI_COLORS = "root=white,black:window=white,black:border=blue,black:listbox=white,black:actlistbox=black,blue:label=white,black:title=brightblue,black:button=white,black:actbutton=black,blue:compactbutton=white,black:checkbox=white,black:actcheckbox=black,blue:entry=white,black:textbox=white,black"

# TODO: wire to config.terminal.emulator when this moves into nix; the
# kronberger user is on rio, the media user on kitty.
def term []: nothing -> string {
  $env.TERMINAL? | default "rio"
}

def drop [...cmd: string] {
  # dropkitten -W/-H are fractions of the screen. The sway branch nudges the
  # popup down by 35px, as dropkittenCmd does.
  let offset = if ($env.SWAYSOCK? | is-not-empty) { ["-y" "35"] } else { [] }
  # Built as one list rather than spread across lines: nushell ends an external
  # command at the newline, so a continuation line parses as a new expression.
  let args = (["-t" (term) "-W" "0.35" "-H" "0.45"] ++ $offset ++ ["--"] ++ $cmd)
  ^@utilLinux@/bin/setsid --fork @dropkitten@/bin/dropkitten ...$args | complete | ignore
}

def main [what: string] {
  match $what {
    "wifi" => {
      drop "bash" "-c" $"NEWT_COLORS=\"($NMTUI_COLORS)\" nmtui connect"
    }
    "audio" => { drop "wiremix" }
    "bluetooth" => { drop "bluetuith" }
    "calendar" => { drop "calcurse" }
    "monitor" => {
      # Straight to the terminal with the app-id niri's window rule matches.
      ^@utilLinux@/bin/setsid --fork (term) --title btop_monitor -e btop | complete | ignore
    }
    _ => { error make {msg: $"unknown tui: ($what)"} }
  }
}
