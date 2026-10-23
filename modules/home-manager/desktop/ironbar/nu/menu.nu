#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# The bar's launcher and power buttons, opening the same sieb menus as niri's
# Mod+D and Mod+Shift+E.
#
# These went through an eww launcher and power menu for a while, then rofi,
# then sieb. The eww launcher spawned Exec= through setsid and steam would not
# start, and eww exposes no key events, so it could not do arrow-key
# navigation.
#
# A script rather than a bare command in the yuck, because widget files are
# copied verbatim and never see replaceVars, so a store path cannot be
# interpolated into one.
#
# One `def main` taking the mode, rather than the `def "main launcher"` pair
# this replaces. Nushell routes `script <sub>` to a `main <sub>` only when a
# bare `def main` exists alongside it; with subcommands alone the script parses,
# defines two commands nothing can reach, and exits 0 without a word. Both
# buttons were dead that way. The match arm below turns the same mistake into an
# error rather than a silence.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const LAUNCHER = "@siebLauncher@"
const POWER    = "@siebPower@"

# Detached, so a menu session does not hang off the bar's click handler.
# lib.nu has the details.
use "@barLib@" *

def main [what: string] {
  match $what {
    "launcher" => { detach $LAUNCHER }
    "power" => { detach $POWER }
    _ => { error make {msg: $"unknown menu: ($what)"} }
  }
}
