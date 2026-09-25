#!@nu@/bin/nu -n

# waybar's built-in `idle_inhibitor`, which eww has no equivalent for.
#
# waybar holds a Wayland idle-inhibitor while activated. A script cannot hold
# one itself (the inhibitor is bound to a surface, so a client has to stay
# connected), so idle-inhibit.service in session-services.nix runs wlinhibit
# to do that, and this toggles the unit. Only the compositor's idle state is
# affected: swayidle keeps running, so its before-sleep hook still locks when
# the lid closes. Note that wayland-pipewire-idle-inhibit.service still runs
# too, so audio playback keeps inhibiting idle independently of this toggle.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const EWW       = "@eww@/bin/eww"
const SYSTEMCTL = "@systemd@/bin/systemctl"

def inhibited? []: nothing -> bool {
  (^$SYSTEMCTL --user is-active idle-inhibit.service | complete).exit_code == 0
}

def status-json []: nothing -> string {
  if (inhibited?) {
    {text: "\u{f06e}", tooltip: "Idle inhibited", class: "activated"}
  } else {
    {text: "\u{f070}", tooltip: "Idle not inhibited", class: "deactivated"}
  } | to json --raw
}

def refresh [] {
  let dir = ($env.FILE_PWD | path dirname)
  ^$EWW -c $dir update $"idle_state=(status-json)" | complete | ignore
}

def main [] { print (status-json) }

def "main toggle" [] {
  if (inhibited?) {
    ^$SYSTEMCTL --user stop idle-inhibit.service | complete | ignore
  } else {
    ^$SYSTEMCTL --user start idle-inhibit.service | complete | ignore
  }
  refresh
}
