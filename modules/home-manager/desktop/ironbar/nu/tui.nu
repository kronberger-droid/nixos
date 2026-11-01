#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Port of waybar.nix's former `tui` attrset and `dropkittenCmd`, in one script.
#
# Five modules open a TUI in a dropdown terminal: network -> nmtui or impala,
# pulseaudio -> wiremix, bluetooth -> bluetui, clock -> calcurse, cpu ->
# bottom. In
# waybar.nix that was a Nix function applied five times; here it is one script
# with a subcommand, so the widgets just call `scripts/tui wifi`.
#
# The TUIs go by store path, like every other script here: the bar's
# PATH is whatever the compositor handed systemd, and a bare name that is not
# on it fails inside the freshly spawned terminal, where nothing shows the
# error but the terminal's own splash.
#
# The system monitor is deliberately not routed through dropkitten: btop,
# which it was until bottom replaced it, needed at least 80x24, and
# dropkitten's fractional sizing came up short, so niri's sysmonitor window
# rule sizes it instead.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const BLUETUI         = "@bluetui@/bin/bluetui"
const BOTTOM          = "@bottom@/bin/btm"
const CALCURSE        = "@calcurse@/bin/calcurse"
const WIREMIX         = "@wiremix@/bin/wiremix"
const DROPKITTEN      = "@dropkitten@/bin/dropkitten"
# nmtui with the bar's colours, or impala once iwd replaces NetworkManager;
# ironbar.nix picks.
const WIFI_TUI        = "@wifiTui@"

use "@barLib@" *

def drop [--width: number = 0.35, --height: number = 0.45, ...cmd: string] {
  # dropkitten -W/-H take a float as a fraction of the screen and an int as
  # logical pixels.
  # -t takes one of dropkitten's known terminal names, not a path, so this is
  # config.terminal.emulator rather than config.terminal.bin.
  # Built as one list rather than spread across lines: nushell ends an external
  # command at the newline, so a continuation line parses as a new expression.
  let size = ["-W" ($width | into string) "-H" ($height | into string)]
  let args = (["-t" "@terminalEmulator@"] ++ $size ++ ["--"] ++ $cmd)
  detach $DROPKITTEN ...$args
}

def main [what: string] {
  match $what {
    "wifi" => {
      # impala's tables are fixed-width, the device table alone about 88
      # columns, so the size goes in pixels rather than fractions: 0.6 that
      # fit the laptop panel's width spread across most of a 32" screen, and
      # 0.45 of the panel's 1000 logical rows left the tables cramped. 1000px
      # is about 100 columns of rio's 16px font.
      drop --width 1000 --height 700 $WIFI_TUI
    }
    "audio" => { drop $WIREMIX }
    "bluetooth" => { drop $BLUETUI }
    "calendar" => { drop $CALCURSE }
    "monitor" => {
      # Straight to the terminal with the app-id niri's window rule matches.
      # app-id, not title: a TUI's title arrives via OSC after the window
      # maps, too late for the rule, which is why niri.nix's Mod+Shift+T does
      # the same.
      spawn-terminal sysmonitor $BOTTOM
    }
    _ => { error make {msg: $"unknown tui: ($what)"} }
  }
}
