#!@nu@/bin/nu -n

let on = ((^@mako@/bin/makoctl mode | complete).stdout
  | lines
  | any {|m| $m == "do-not-disturb"})

if $on {
  ^@mako@/bin/makoctl mode -r do-not-disturb | complete | ignore
  ^@libnotify@/bin/notify-send "Do Not Disturb" "Notifications enabled" -i notification | complete | ignore
} else {
  # Deliberately silent going the other way: a notification announcing that
  # notifications are off would be self-defeating.
  ^@mako@/bin/makoctl mode -s do-not-disturb | complete | ignore
}

^@procps@/bin/pkill -RTMIN+11 waybar | complete | ignore
