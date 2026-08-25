#!@nu@/bin/nu -n

# waybar's built-in `idle_inhibitor`, which eww has no equivalent for.
#
# waybar holds a Wayland idle-inhibitor while activated. There is no way to do
# that from a script, so this stops swayidle.service instead: same observable
# effect (the screen stops locking and blanking), and it is honest about the
# mechanism. Note that wayland-pipewire-idle-inhibit.service still runs, so
# audio playback keeps inhibiting idle independently of this toggle.

def inhibited? []: nothing -> bool {
  (^@systemd@/bin/systemctl --user is-active swayidle.service | complete).exit_code != 0
}

def status-json []: nothing -> string {
  if (inhibited?) {
    {text: "\u{f06e}", tooltip: "Idle inhibited (swayidle stopped)", class: "activated"}
  } else {
    {text: "\u{f070}", tooltip: "Idle not inhibited", class: "deactivated"}
  } | to json --raw
}

def refresh [] {
  let dir = ($env.FILE_PWD | path dirname)
  ^@eww@/bin/eww -c $dir update $"idle_state=(status-json)" | complete | ignore
}

def main [] { print (status-json) }

def "main toggle" [] {
  if (inhibited?) {
    ^@systemd@/bin/systemctl --user start swayidle.service | complete | ignore
  } else {
    ^@systemd@/bin/systemctl --user stop swayidle.service | complete | ignore
  }
  refresh
}
