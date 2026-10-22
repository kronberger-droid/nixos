#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib
#
# niri is called bare rather than by store path: the binary is on PATH inside
# its own session. scratchpad-toggle.nu set this precedent.

# Workspace state for eww, as a `deflisten` source: one JSON line per change.
#
# Design: every relevant event triggers a full re-query rather than patching a
# local copy. niri sends WorkspacesChanged with the whole list, but
# WorkspaceActivated carries only an id, so an incremental version would have to
# hold state and could drift out of sync. Workspace changes happen at human
# speed and the query costs a few ms, so re-asking is both simpler and always
# correct. Same reasoning as the niri-window-watcher the waybar config used to
# carry, which signalled waybar to re-poll rather than passing any state along.
#
# Sorted by idx, because niri returns workspaces unordered:
#
#   [{idx, name, output, active, focused, urgent}, ...]
#
#   active  = visible on its output  (niri is_active)
#   focused = holds keyboard focus   (niri is_focused)
#
# waybar needed both too; its style.css said "Sway uses .focused, Niri uses
# .active".

# A failed query (niri restarting, say) yields an empty list instead of an
# error, which would end the deflisten for good.
def niri-state []: nothing -> list {
  let r = (^niri msg --json workspaces | complete)
  if $r.exit_code != 0 { return [] }
  $r.stdout
  | from json
  | sort-by idx
  | each {|w| {
      idx: $w.idx
      name: ($w.name | default ($w.idx | into string))
      output: $w.output
      active: $w.is_active
      focused: $w.is_focused
      urgent: $w.is_urgent
    }}
}

def emit [state: list] {
  $state | to json --raw | print
}

# Click target for a workspace pill.
def "main focus" [idx: int] {
  if ($env.NIRI_SOCKET? | is-not-empty) {
    ^niri msg action focus-workspace $idx | complete | ignore
  }
}

def main [] {
  if ($env.NIRI_SOCKET? | is-not-empty) {
    # No initial emit here: niri sends WorkspacesChanged the moment the stream
    # connects, so the loop below produces the first line on its own.
    #
    # Every workspace-relevant event name starts with "Workspace", which covers
    # WorkspacesChanged, WorkspaceActivated, WorkspaceActiveWindowChanged and
    # WorkspaceUrgencyChanged. Window events are far noisier and none of them
    # change what this widget draws.
    ^niri msg --json event-stream
    | lines
    | each {|line|
        if ($line | str starts-with '{"Workspace') { emit (niri-state) }
      }
    | ignore
  }
}
