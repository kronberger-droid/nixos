#!@nu@/bin/nu -n

# Near-twin of ncspot-toggle.nu, as the bash versions were. A shared module
# would have to resolve its path at runtime relative to the installed file.

def niri-windows [] {
  let r = (^niri msg -j windows | complete)
  if $r.exit_code == 0 { $r.stdout | from json } else { [] }
}

def window-id [app_id: string] {
  niri-windows | where app_id? == $app_id | get 0?.id?
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
  # and the refresh below only run afterwards.
  ^@terminalBin@ @terminalAppIdFlag@ $app_id @terminalExecFlag@ @zellij@/bin/zellij attach $session --create | complete | ignore
  await-state $app_id "open"
}

^@procps@/bin/pkill -RTMIN+12 waybar | complete | ignore
