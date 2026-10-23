#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Toggles the spotify_player popup. The widget is a plain button with no
# status half.
#
# Same toggle as scratchpad.nu, but without zellij: zellij drops the kitty
# graphics protocol, so the cover art never reached the terminal. zellij was
# only there to keep playback alive when the popup closed, and the
# spotify-player daemon in music.nix now does that. The TUI here is a remote
# for it, so closing the window just closes the UI.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const SPOTIFY_PLAYER  = "@spotifyPlayer@"
const SPOTIFY_DEVICE  = "@spotifyDevice@"

use "@barLib@" *

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
  let app_id = "spotify_popup"
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
    # With `DaemonOnly` the TUI has no device of its own and attaches to
    # whichever one is active, or the first listed, often another host's.
    # Moving playback onto the local daemon first leaves it nothing else to
    # pick. The daemon serves the request; play/pause state carries over.
    ^$SPOTIFY_PLAYER connect --name $SPOTIFY_DEVICE | complete | ignore
    # The daemon already owns the MPRIS name; a second registration from the
    # TUI would show up as a duplicate player in the mpris widget. Detached,
    # so the script returns once the window is up instead of when it closes.
    spawn-terminal $app_id ...[$SPOTIFY_PLAYER "-o" "enable_media_control=false"]
    await-state $app_id "open"
  }
}
