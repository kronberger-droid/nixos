#!@nu@/bin/nu -n

# One bar per output, opened and closed as monitors come and go.
#
# waybar got this for free: its `output` field matches per monitor and it
# handles hotplug itself. eww has no equivalent, and its `defwindow bar
# [mon] :monitor mon` takes the output name as a window argument, so the one
# definition is opened once per screen under its own `--id`. Each instance
# filters the shared `workspaces` deflisten down to its own output, so there
# is still exactly one niri event stream behind both bars.
#
# niri has no output event. Its IPC Event enum carries Workspace*, Window*,
# Keyboard*, Overview, Config, Screenshot and Cast variants and nothing for
# monitors at all, so there is nothing better to wait on. WorkspacesChanged
# is the usable proxy: niri keeps an empty workspace on every output, so
# add_output moves workspaces onto the new screen and the next ipc refresh
# diffs the set and fires the event. Connecting or disconnecting a monitor
# therefore always produces one.
#
# Reconciling from scratch on every event rather than tracking what was
# opened, for the same reason workspaces.nu re-queries instead of patching:
# the daemon already knows which bars exist, and asking costs a few ms at
# human speed. It also makes the script idempotent, so a spurious event or a
# manual re-run is harmless.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const EWW = "@eww@/bin/eww"

def bar-id [out: string]: nothing -> string { $"bar-($out)" }

# niri keys its outputs object by connector name; sway returns a list.
def outputs []: nothing -> list<string> {
  if ($env.NIRI_SOCKET? | is-not-empty) {
    let r = (^niri msg --json outputs | complete)
    if $r.exit_code != 0 { return [] }
    $r.stdout | from json | columns
  } else if ($env.SWAYSOCK? | is-not-empty) {
    # UNTESTED, like workspaces.nu's sway arm. `active` filters out outputs
    # sway knows about but is not driving.
    let r = (^swaymsg -t get_outputs --raw | complete)
    if $r.exit_code != 0 { return [] }
    $r.stdout | from json | where active | get name
  } else {
    []
  }
}

# `eww active-windows` prints "<id>: <window-name>" per line. Reading the ids
# back off the daemon is what lets this hold no state of its own.
def open-bars []: nothing -> list<string> {
  let r = (^$EWW active-windows | complete)
  if $r.exit_code != 0 { return [] }
  ($r.stdout
   | lines
   | each {|l| $l | split row ":" | get 0? | default "" | str trim }
   | where {|id| $id | str starts-with "bar-" })
}

def reconcile [] {
  let want = (outputs)
  let want_ids = ($want | each {|o| bar-id $o })
  let have = (open-bars)

  # Close first: a disconnected output's bar is already gone from the screen,
  # but eww still counts it open and would skip reopening after a replug.
  for id in ($have | where {|h| $h not-in $want_ids }) {
    ^$EWW close $id | complete | ignore
  }
  for o in ($want | where {|o| (bar-id $o) not-in $have }) {
    ^$EWW open bar --id (bar-id $o) --arg $"mon=($o)" | complete | ignore
  }
}

# Reconcile once and exit. Not used by the unit; this is the handle for
# checking what the watcher would do, and for re-syncing by hand if the
# daemon and the outputs ever disagree.
def "main once" [] { reconcile }

def main [] {
  # The daemon counts as active the moment the process starts, but its IPC
  # socket appears a little later. The ExecStartPost script this replaces
  # retried `eww open` for the same reason; `ping` says it more directly.
  for _ in 1..25 {
    if (^$EWW ping | complete).exit_code == 0 { break }
    sleep 200ms
  }

  reconcile

  if ($env.NIRI_SOCKET? | is-not-empty) {
    ^niri msg --json event-stream
    | lines
    | each {|line|
        if ($line | str starts-with '{"WorkspacesChanged') { reconcile }
      }
    | ignore
  } else if ($env.SWAYSOCK? | is-not-empty) {
    # UNTESTED. sway does have a real output event, so no proxy needed here.
    ^swaymsg -t subscribe -m '["output"]'
    | lines
    | each {|_| reconcile }
    | ignore
  }
}
