#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Screen recording, merged from waybar/nu/screenrec-status.nu and
# screenrec-toggle.nu. The recording logic is unchanged.
#
# The mode picker (area/output) and the output picker are sieb in dmenu mode,
# themed by the launcher's config.toml. Escape exits sieb with 1 and empty
# stdout, which the match below already reads as "abort".

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const EWW          = "@eww@/bin/eww"
const NOTIFY_SEND  = "@libnotify@/bin/notify-send"
const PGREP        = "@procps@/bin/pgrep"
const PKILL        = "@procps@/bin/pkill"
const SETSID       = "@utilLinux@/bin/setsid"
const SIEB         = "@siebBin@"
const SLURP        = "@slurp@/bin/slurp"
const WL_SCREENREC = "@wlScreenrec@/bin/wl-screenrec"

def status-json []: nothing -> string {
  if (recording?) {
    {text: "REC", class: "recording"} | to json --raw
  } else {
    # waybar hides the module on empty output; eww needs a shape it can parse.
    {text: "", class: "idle"} | to json --raw
  }
}

def main [] { print (status-json) }


def recording? [] {
  (^$PGREP -x wl-screenrec | complete).exit_code == 0
}

def notify [body: string] {
  ^$NOTIFY_SEND "Screen Recording" $body | complete | ignore
}

def refresh [] {
  let dir = ($env.FILE_PWD | path dirname)
  ^$EWW -c $dir update $"screenrec_state=(status-json)" | complete | ignore
}

# Same shape as the `detach` in utilities.nu. Nushell has no `&`, and its
# `job spawn` runs in a thread of *this* process, so a recording started that
# way would die when this script exits.
def detach [...cmd: string] {
  ^$SETSID -f ...$cmd out> /dev/null err> /dev/null
}

def "main toggle" [] {
  if (recording?) {
    ^$PKILL wl-screenrec | complete | ignore
    notify "Recording stopped"
    refresh
    return
  }

  let mode = ("area\noutput"
    | ^$SIEB -p "Record"
    | complete
    | get stdout
    | str trim)

  # Each arm returns the wl-screenrec selection flags, or null to abort.
  let selection = match $mode {
    "area" => {
      let geometry = (^$SLURP | complete | get stdout | str trim)
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
          | ^$SIEB -p "Output"
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
  let record_args = [$WL_SCREENREC ...$selection "-f" $filename]
  detach ...$record_args

  notify $"Recording started: ($filename | path basename)"
  refresh
}
