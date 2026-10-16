#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Port of waybar.nix's former `tui` attrset and `dropkittenCmd`, in one script.
#
# Five modules open a TUI in a dropdown terminal: network -> nmtui, pulseaudio
# -> wiremix, bluetooth -> bluetuith, clock -> calcurse, cpu -> btop. In
# waybar.nix that was a Nix function applied five times; here it is one script
# with a subcommand, so the widgets just call `scripts/tui wifi`.
#
# The TUIs go by store path, like every other script here: the eww daemon's
# PATH is whatever the compositor handed systemd, and a bare name that is not
# on it fails inside the freshly spawned terminal, where nothing shows the
# error but the terminal's own splash.
#
# btop is deliberately not routed through dropkitten: waybar.nix noted that
# btop needs at least 80x24 and dropkitten's fractional sizing came up short,
# so niri's btop_monitor window rule sizes it instead.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const BTOP            = "@btop@/bin/btop"
const DROPKITTEN      = "@dropkitten@/bin/dropkitten"

use "@ewwLib@" *

const NMTUI_COLORS = "root=white,black:window=white,black:border=blue,black:listbox=white,black:actlistbox=black,blue:label=white,black:title=brightblue,black:button=white,black:actbutton=black,blue:compactbutton=white,black:checkbox=white,black:actcheckbox=black,blue:entry=white,black:textbox=white,black"

def drop [...cmd: string] {
  # dropkitten -W/-H are fractions of the screen.
  # -t takes one of dropkitten's known terminal names, not a path, so this is
  # config.terminal.emulator rather than config.terminal.bin.
  # Built as one list rather than spread across lines: nushell ends an external
  # command at the newline, so a continuation line parses as a new expression.
  let args = (["-t" "@terminalEmulator@" "-W" "0.35" "-H" "0.45" "--"] ++ $cmd)
  detach $DROPKITTEN ...$args
}

def main [what: string] {
  match $what {
    "wifi" => {
      drop "@bash@/bin/bash" "-c" $"NEWT_COLORS=\"($NMTUI_COLORS)\" @networkmanager@/bin/nmtui connect"
    }
    "audio" => { drop "@wiremix@/bin/wiremix" }
    "bluetooth" => { drop "@bluetuith@/bin/bluetuith" }
    "calendar" => { drop "@calcurse@/bin/calcurse" }
    "monitor" => {
      # Straight to the terminal with the app-id niri's window rule matches.
      # app-id, not title: btop's title arrives via OSC after the window maps,
      # too late for the rule, which is why niri.nix's Mod+Shift+T does the
      # same.
      spawn-terminal btop_monitor $BTOP
    }
    _ => { error make {msg: $"unknown tui: ($what)"} }
  }
}
