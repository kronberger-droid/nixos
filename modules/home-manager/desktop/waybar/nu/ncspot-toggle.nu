#!@nu@/bin/nu -n

# See scratchpad-toggle.nu: same shape, different spawn branch. No waybar
# refresh at the end, matching the bash version.

def niri-windows [] {
  let r = (^niri msg -j windows | complete)
  if $r.exit_code == 0 { $r.stdout | from json } else { [] }
}

def window-id [app_id: string] {
  niri-windows | where app_id? == $app_id | get 0?.id?
}

def await-state [app_id: string, want: string] {
  for _ in 1..20 {
    let present = ((window-id $app_id) != null)
    if ($want == "open" and $present) or ($want == "closed" and (not $present)) {
      return
    }
    sleep 50ms
  }
}

let app_id = "ncspot_popup"
let session = "ncspot"
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
  # Drop a resurrectable-but-dead session of the same name so we don't attach
  # to a ghost where ncspot is no longer running.
  let dead = (^@zellij@/bin/zellij list-sessions -n | complete | get stdout | lines)
  if ($dead | any {|l| ($l | str starts-with $"($session) ") and ($l | str contains "EXITED")}) {
    ^@zellij@/bin/zellij delete-session $session --force | complete | ignore
  }

  # `-s` lists live session names only, so this is an exact match.
  let live = (^@zellij@/bin/zellij list-sessions -s -n | complete | get stdout | lines)
  if ($live | any {|l| $l == $session}) {
    ^@terminalBin@ @terminalAppIdFlag@ $app_id @terminalExecFlag@ @zellij@/bin/zellij attach $session | complete | ignore
  } else {
    ^@terminalBin@ @terminalAppIdFlag@ $app_id @terminalExecFlag@ @zellij@/bin/zellij -s $session -n ncspot | complete | ignore
  }
  await-state $app_id "open"
}
