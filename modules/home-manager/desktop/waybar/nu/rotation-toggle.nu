#!@nu@/bin/nu -n

# The state file is the persistent preference, not a record of what is running:
# rot8.service's ExecCondition (session-services.nix) skips the unit while the
# file exists, which is what carries the choice across a reboot. systemd owns
# the process, so this only sets the preference and nudges the unit.
let state_file = ($env.HOME | path join ".cache" "rotation-state")
let enabling = ($state_file | path exists)

if $enabling {
  rm --force $state_file
  # `restart` rather than `start`: ExecCondition runs on every start attempt
  # and has to see the file already gone.
  ^@systemd@/bin/systemctl --user restart rot8.service | complete | ignore
} else {
  touch $state_file
  ^@systemd@/bin/systemctl --user stop rot8.service | complete | ignore
}

let state = if $enabling { "enabled" } else { "disabled" }
^@libnotify@/bin/notify-send "Auto-rotation" $"Screen auto-rotation ($state)" -i display-brightness | complete | ignore

^@procps@/bin/pkill -RTMIN+9 waybar | complete | ignore
