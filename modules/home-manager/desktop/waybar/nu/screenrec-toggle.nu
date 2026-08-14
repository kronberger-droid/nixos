#!@nu@/bin/nu -n

def recording? [] {
  (^@procps@/bin/pgrep -x wl-screenrec | complete).exit_code == 0
}

def notify [body: string] {
  ^@libnotify@/bin/notify-send "Screen Recording" $body | complete | ignore
}

def refresh [] {
  ^@procps@/bin/pkill -RTMIN+10 waybar | complete | ignore
}

# Same shape as the `detach` in utilities.nu. Nushell has no `&`, and its
# `job spawn` runs in a thread of *this* process, so a recording started that
# way would die when this script exits.
def detach [...cmd: string] {
  ^@utilLinux@/bin/setsid -f ...$cmd out> /dev/null err> /dev/null
}

if (recording?) {
  ^@procps@/bin/pkill wl-screenrec | complete | ignore
  notify "Recording stopped"
  refresh
  exit 0
}

let mode = ("area\noutput"
  | ^@rofi@/bin/rofi -dmenu -p "Record" -theme-str 'listview {lines: 2;}'
  | complete
  | get stdout
  | str trim)

# Each arm returns the wl-screenrec selection flags, or null to abort.
let selection = match $mode {
  "area" => {
    let geometry = (^@slurp@/bin/slurp | complete | get stdout | str trim)
    if ($geometry | is-empty) { null } else { ["-g" $geometry] }
  }
  "output" => {
    # Output names are the keys of `msg -j outputs`.
    let outputs = (^niri msg -j outputs | complete)
    if $outputs.exit_code != 0 {
      null
    } else {
      let picked = ($outputs.stdout
        | from json
        | columns
        | str join "\n"
        | ^@rofi@/bin/rofi -dmenu -p "Output" -theme-str 'listview {lines: 3;}'
        | complete
        | get stdout
        | str trim)
      if ($picked | is-empty) { null } else { ["-o" $picked] }
    }
  }
  _ => null
}

if $selection == null { exit 0 }

let dir = ($env.HOME | path join "Videos")
mkdir $dir
let filename = ($dir | path join $"recording-((date now | format date '%Y-%m-%d-%H-%M-%S')).mp4")

# Spread as one list: a literal `-f` in the argument list would be parsed as a
# flag to `detach` and fail at parse time. Spread values are not reinterpreted.
let record_args = [@wlScreenrec@/bin/wl-screenrec ...$selection "-f" $filename]
detach ...$record_args

notify $"Recording started: ($filename | path basename)"
refresh
