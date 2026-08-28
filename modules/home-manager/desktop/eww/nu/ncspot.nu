#!@nu@/bin/nu -n

# Copied from waybar/nu/ncspot-toggle.nu, logic unchanged.
#
# waybar's custom/ncspot is a static icon: `interval = "once"` over an echoed
# JSON literal, with the real work in this script. So unlike the scratchpad
# there is no status half to port, and the widget is a plain button.
#
# See scratchpad.nu: same shape, different spawn branch. The zellij session is
# started with `-n ncspot` when it does not exist, and attached when it does.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const TERMINAL        = "@terminalBin@"
const TERM_APPID_FLAG = "@terminalAppIdFlag@"
const TERM_EXEC_FLAG  = "@terminalExecFlag@"
const ZELLIJ          = "@zellij@/bin/zellij"

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

def main [] {
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
    let dead = (^$ZELLIJ list-sessions -n | complete | get stdout | lines)
    if ($dead | any {|l| ($l | str starts-with $"($session) ") and ($l | str contains "EXITED")}) {
      ^$ZELLIJ delete-session $session --force | complete | ignore
    }

    # `-s` lists live session names only, so this is an exact match.
    let live = (^$ZELLIJ list-sessions -s -n | complete | get stdout | lines)
    if ($live | any {|l| $l == $session}) {
      ^$TERMINAL $TERM_APPID_FLAG $app_id $TERM_EXEC_FLAG $ZELLIJ attach $session | complete | ignore
    } else {
      ^$TERMINAL $TERM_APPID_FLAG $app_id $TERM_EXEC_FLAG $ZELLIJ -s $session -n ncspot | complete | ignore
    }
    await-state $app_id "open"
  }
}
