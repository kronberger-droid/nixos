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
#
# Null, not an empty list, when the query fails: an empty set of outputs is a
# meaningful answer here (it closes every bar), and a compositor that did not
# answer must not be read as one driving no screens.
def outputs []: nothing -> any {
  if ($env.NIRI_SOCKET? | is-not-empty) {
    let r = (^niri msg --json outputs | complete)
    if $r.exit_code != 0 { return null }
    $r.stdout | from json | columns
  } else if ($env.SWAYSOCK? | is-not-empty) {
    # UNTESTED, like workspaces.nu's sway arm. `active` filters out outputs
    # sway knows about but is not driving.
    let r = (^swaymsg -t get_outputs --raw | complete)
    if $r.exit_code != 0 { return null }
    $r.stdout | from json | where active | get name
  } else {
    # No compositor socket at all. Nothing to draw on, and unlike the two
    # failures above this will not fix itself, so it stays an empty list.
    []
  }
}

# `eww active-windows` prints "<id>: <window-name>" per line. Reading the ids
# back off the daemon is what lets this hold no state of its own. Null on
# failure for the same reason as `outputs`: an unreachable daemon read as "no
# bars are open" would have reconcile open one per output against nothing.
def open-bars []: nothing -> any {
  let r = (^$EWW active-windows | complete)
  if $r.exit_code != 0 { return null }
  ($r.stdout
   | lines
   | each {|l| $l | split row ":" | get 0? | default "" | str trim }
   | where {|id| $id | str starts-with "bar-" })
}

# True when the pass reached the daemon and the compositor and did what it
# wanted. A false is always transient (a restart in flight, or a query that did
# not come back), so the caller retries rather than dropping the pass.
def reconcile []: nothing -> bool {
  let want = (outputs)
  let have = (open-bars)
  if ($want == null) or ($have == null) { return false }

  let want_ids = ($want | each {|o| bar-id $o })
  mut ok = true

  # Close first: a disconnected output's bar is already gone from the screen,
  # but eww still counts it open and would skip reopening after a replug.
  for id in ($have | where {|h| $h not-in $want_ids }) {
    if (^$EWW close $id | complete).exit_code != 0 { $ok = false }
  }
  for o in ($want | where {|o| (bar-id $o) not-in $have }) {
    let r = (^$EWW open bar --id (bar-id $o) --arg $"mon=($o)" | complete)
    if $r.exit_code != 0 { $ok = false }
  }
  $ok
}

# The daemon is reachable whenever this script runs (eww.service gates its own
# start on `eww ping`), so a failed pass means the daemon went away underneath
# us. Retrying is cheap and, since eww is wrapped with --no-daemonize, a failed
# `eww open` is now a no-op rather than a second eww server drawing its own bar.
def reconcile-until-ok [] {
  for _ in 1..25 {
    if (reconcile) { return }
    sleep 200ms
  }
  print -e "bars: could not reconcile against the daemon, waiting for the next event"
}

# Reconcile once and exit. Not used by the unit; this is the handle for
# checking what the watcher would do, and for re-syncing by hand if the
# daemon and the outputs ever disagree.
def "main once" [] { reconcile | ignore }

def main [] {
  # No wait for the daemon here. eww.service holds its own start job open
  # until `eww ping` answers, so systemd's ordering already guarantees a
  # reachable server by the time this unit runs, on a restart as much as at
  # login. The loop that used to sit here polled ping and then opened the bars
  # over a second connection, which left exactly the window this landed in.
  reconcile-until-ok

  if ($env.NIRI_SOCKET? | is-not-empty) {
    ^niri msg --json event-stream
    | lines
    | each {|line|
        if ($line | str starts-with '{"WorkspacesChanged') { reconcile-until-ok }
      }
    | ignore
  } else if ($env.SWAYSOCK? | is-not-empty) {
    # UNTESTED. sway does have a real output event, so no proxy needed here.
    ^swaymsg -t subscribe -m '["output"]'
    | lines
    | each {|_| reconcile-until-ok }
    | ignore
  }
}
