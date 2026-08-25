#!@nu@/bin/nu -n

# Do Not Disturb, merged from waybar/nu/dnd-status.nu and dnd-toggle.nu.
# Logic unchanged; only the refresh differs, since eww has no signal mechanism.

def on? []: nothing -> bool {
  ((^@mako@/bin/makoctl mode | complete).stdout
   | lines
   | any {|m| $m == "do-not-disturb"})
}

def refresh [] {
  let dir = ($env.FILE_PWD | path dirname)
  ^@eww@/bin/eww -c $dir update $"dnd_state=(status-json)" | complete | ignore
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
    ^@mako@/bin/makoctl mode -r do-not-disturb | complete | ignore
    ^@libnotify@/bin/notify-send "Do Not Disturb" "Notifications enabled" -i notification | complete | ignore
  } else {
    # Deliberately silent going the other way: a notification announcing that
    # notifications are off would be self-defeating.
    ^@mako@/bin/makoctl mode -s do-not-disturb | complete | ignore
  }
  refresh
}
