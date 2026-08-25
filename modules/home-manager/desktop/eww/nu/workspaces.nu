#!@nu@/bin/nu -n
#
# niri and swaymsg are called bare rather than by store path. waybar.nix has to
# gate its niri interpolation on compositor.primary, because pulling the
# source-built niri fork into a sway-only host's closure is expensive; calling
# them bare sidesteps that, and the binary is on PATH inside its own session.
# scratchpad-toggle.nu set this precedent.

# Workspace state for eww, as a `deflisten` source: one JSON line per change.
#
# Design: every relevant event triggers a full re-query rather than patching a
# local copy. niri sends WorkspacesChanged with the whole list, but
# WorkspaceActivated carries only an id, so an incremental version would have to
# hold state and could drift out of sync. Workspace changes happen at human
# speed and the query costs a few ms, so re-asking is both simpler and always
# correct. Same reasoning as waybar.nix's niri-window-watcher, which signals
# waybar to re-poll rather than passing any state along.
#
# The shape is normalised across compositors so the widget need not care which
# one is running. Sorted by idx, because niri returns workspaces unordered:
#
#   [{idx, name, output, active, focused, urgent}, ...]
#
#   active  = visible on its output  (niri is_active,  sway visible)
#   focused = holds keyboard focus   (niri is_focused, sway focused)
#
# waybar needed both too; its style.css says "Sway uses .focused, Niri uses
# .active".

def niri-state []: nothing -> list {
  (^niri msg --json workspaces | complete).stdout
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

# UNTESTED: this machine runs niri, so the sway arm has never been exercised.
# Field names are from `swaymsg -t get_workspaces`.
def sway-state []: nothing -> list {
  (^swaymsg -t get_workspaces --raw | complete).stdout
  | from json
  | sort-by num
  | each {|w| {
      idx: $w.num
      name: $w.name
      output: $w.output
      active: $w.visible
      focused: $w.focused
      urgent: $w.urgent
    }}
}

def emit [state: list] {
  $state | to json --raw | print
}

# Click target for a workspace pill.
def "main focus" [idx: int] {
  if ($env.NIRI_SOCKET? | is-not-empty) {
    ^niri msg action focus-workspace $idx | complete | ignore
  } else if ($env.SWAYSOCK? | is-not-empty) {
    ^swaymsg workspace number $idx | complete | ignore
  }
}

def main [] {
  if ($env.NIRI_SOCKET? | is-not-empty) {
    # No initial emit here: niri sends WorkspacesChanged the moment the stream
    # connects, so the loop below produces the first line on its own. sway's
    # subscribe does not, hence the asymmetry further down.
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
  } else if ($env.SWAYSOCK? | is-not-empty) {
    emit (sway-state)
    ^swaymsg -t subscribe -m '["workspace"]'
    | lines
    | each {|_| emit (sway-state) }
    | ignore
  }
}
