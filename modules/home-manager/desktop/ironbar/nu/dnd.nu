#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Do Not Disturb, merged from waybar/nu/dnd-status.nu and dnd-toggle.nu.
# A toggle pushes its new state to the bar rather than waiting for the poll.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const BRIDGE      = "@bridge@"
const MAKOCTL     = "@mako@/bin/makoctl"
const NOTIFY_SEND = "@libnotify@/bin/notify-send"

def on? []: nothing -> bool {
  ((^$MAKOCTL mode | complete).stdout
   | lines
   | any {|m| $m == "do-not-disturb"})
}

def refresh [] {
  ^$BRIDGE push dnd (status-json)
}

def status-json []: nothing -> string {
  if (on?) {
    {text: "\u{f1f6}", alt: "on", tooltip: "Do Not Disturb: ON", class: "on"}
  } else {
    {text: "\u{f0f3}", alt: "off", tooltip: "Do Not Disturb: OFF", class: "off"}
  } | to json --raw
}

def main [] { print (status-json) }

def "main toggle" [] {
  if (on?) {
    ^$MAKOCTL mode -r do-not-disturb | complete | ignore
    ^$NOTIFY_SEND "Do Not Disturb" "Notifications enabled" -i notification | complete | ignore
  } else {
    # Deliberately silent going the other way: a notification announcing that
    # notifications are off would be self-defeating.
    ^$MAKOCTL mode -s do-not-disturb | complete | ignore
  }
  refresh
}
