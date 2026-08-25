#!@nu@/bin/nu -n

# Zellij scratchpad, merged from waybar/nu/scratchpad-status.nu and
# scratchpad-toggle.nu. The toggle logic is unchanged.
#
# The status half is now a deflisten rather than a polled script. waybar needed
# a separate systemd unit for this — niri-window-watcher.service in waybar.nix
# tails `niri msg event-stream` and sends SIGRTMIN+12 to waybar on any window
# event, because waybar has no way to consume a stream directly. eww does, so
# the watcher folds into this script and the unit is not needed.
#
# niri is called bare rather than by store path, as the originals do: this only
# ever runs inside the niri session.

def niri-windows []: nothing -> list {
  let r = (^niri msg -j windows | complete)
  if $r.exit_code == 0 { $r.stdout | from json } else { [] }
}

def window-id [app_id: string]: nothing -> any {
  niri-windows | where app_id? == $app_id | get 0?.id?
}

def status-json []: nothing -> string {
  let open = ((window-id "scratchpad") != null)
  if $open {
    {text: "\u{f489}", alt: "open", tooltip: "Scratchpad open", class: "open"}
  } else {
    {text: "\u{f489}", alt: "closed", tooltip: "Scratchpad closed", class: "closed"}
  } | to json --raw
}

# deflisten source: emit once, then on every window event.
def main [] {
  print (status-json)
  ^niri msg --json event-stream
  | lines
  | each {|line|
      if ($line | str starts-with '{"Window') { print (status-json) }
    }
  | ignore
}

# niri applies window actions asynchronously; poll for one second, then quit.
def await-state [app_id: string, want: string] {
  for _ in 1..20 {
    let present = ((window-id $app_id) != null)
    if ($want == "open" and $present) or ($want == "closed" and (not $present)) {
      return
    }
    sleep 50ms
  }
}

def "main toggle" [] {
  let app_id = "scratchpad"
  let session = "scratchpad"
  let id = (window-id $app_id)

  if $id != null {
    let focused = (^niri msg -j focused-window | complete)
    let focused_app = (if $focused.exit_code == 0 {
      $focused.stdout | from json | get app_id?
    } else {
      null
    })

    if $focused_app == $app_id {
      ^niri msg action close-window --id $id | complete | ignore
      await-state $app_id "closed"
    } else {
      ^niri msg action focus-window --id $id | complete | ignore
    }
  } else {
    # Drop a resurrectable-but-dead session so `attach --create` makes a fresh
    # one instead of restoring an empty shell where yazi used to be.
    let sessions = (^@zellij@/bin/zellij list-sessions -n | complete | get stdout | lines)
    if ($sessions | any {|l| ($l | str starts-with $"($session) ") and ($l | str contains "EXITED")}) {
      ^@zellij@/bin/zellij delete-session $session --force | complete | ignore
    }

    # Foreground, as in bash: blocks until the terminal exits, so await-state
    # only runs afterwards.
    ^@terminalBin@ @terminalAppIdFlag@ $app_id @terminalExecFlag@ @zellij@/bin/zellij attach $session --create | complete | ignore
    await-state $app_id "open"
  }

  # No refresh call: the deflisten above sees the window event itself.
}
