#!@nu@/bin/nu -n

# STUB (1 of 2). Pinned to bash in waybar.nix until this is written.
# rotation-status.nu next door is the worked example for the other half.
#
# From rotation-toggle.sh:
#   state file exists  -> rotation is DISABLED. Remove it, start @rot8@/bin/rot8
#                         detached, notify "Screen auto-rotation enabled".
#   state file missing -> rotation is ENABLED. Create it, @procps@/bin/pkill
#                         rot8, notify "Screen auto-rotation disabled".
#   Both notifications: @libnotify@/bin/notify-send "Auto-rotation" <body>
#                       -i display-brightness
#
# `rm`, `touch` and `path exists` are builtins, so no coreutils. The gotcha is
# that a non-zero exit from an external aborts a nu script rather than
# continuing, and pkill exits 1 when it matched nothing.

def detach [...cmd: string] {
  ^@utilLinux@/bin/setsid -f ...$cmd out> /dev/null err> /dev/null
}

let state_file = ($env.HOME | path join ".cache" "rotation-state")

# TODO: the toggle goes here.

^@procps@/bin/pkill -RTMIN+9 waybar | complete | ignore
