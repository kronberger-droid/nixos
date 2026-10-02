#!@nu@/bin/nu -n

# The bar's launcher and power buttons, opening the same sieb menus as niri's
# Mod+D and Mod+Shift+E.
#
# These went through an eww launcher and power menu for a while, then rofi,
# then sieb. The eww launcher spawned Exec= through setsid and steam would not
# start, and eww exposes no key events, so it could not do arrow-key
# navigation. sieb's power menu knows sway's logout as well as niri's, and its
# window mode says it needs niri rather than failing, so sway gets these too.
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

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const LAUNCHER = "@siebLauncher@"
const POWER    = "@siebPower@"
const SETSID   = "@utilLinux@/bin/setsid"

# Detached, and screenrec.nu's shape rather than tui.nu's. eww kills an onclick
# handler that outlives the widget's :timeout, 200ms by default, which is what
# the "command ... timed out" lines in the journal are; anything that waits on a
# menu session has to leave the process tree first.
#
# The redirects, not `| complete | ignore`, are what does the leaving. `complete`
# waits for EOF on the pipe rather than for the process, and the detached
# grandchild inherits the write end, so it blocks for as long as the thing it
# just detached from stays alive: measured at the full two minutes for a
# `setsid --fork sleep 120`. Fresh descriptors return in 11ms instead.
def detach [...cmd: string] {
  ^$SETSID -f ...$cmd out> /dev/null err> /dev/null
}

def main [what: string] {
  match $what {
    "launcher" => { detach $LAUNCHER }
    "power" => { detach $POWER }
    _ => { error make {msg: $"unknown menu: ($what)"} }
  }
}
