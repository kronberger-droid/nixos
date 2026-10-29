#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Saves the focused niri workspace and rebuilds it later from a sieb picker.
#
# Not a session restore: no scrollback, no running programs. What comes back
# is the layout, which columns hold which windows at roughly which width:
#
# - terminals, in the directory their shell was in, running what they ran
#   if that is on the RERUN list (helix, claude, ...), inside a shell so
#   quitting it leaves a prompt there; anything else comes back as the
#   bare shell, since rerunning a `cargo run` or an `rm` on open is no help
# - Helium windows, as fresh ones; Chromium has no way to list one window's
#   tabs from outside short of the remote debugging port, so the tabs stay
#   with Helium's own session restore
# - anything else, by rerunning its command line from its directory, which
#   brings zathura back on the same PDF
#
# `main save` asks for a name, offering the saved ones to overwrite; Enter
# on a name nothing matches takes it as typed. `main close` saves the same
# way and then closes the workspace's windows, so it is out of the way until
# picked again; Escape at the prompt closes nothing. `main` picks a save and
# rebuilds it on the focused workspace, right of whatever is there, and
# names the workspace after it unless it has a name already. Picking a save
# whose workspace is still open only focuses that one.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const ENV_BIN      = "@coreutils@/bin/env"
const HELIUM       = "@helium@/bin/helium"
const NOTIFY_SEND  = "@libnotify@/bin/notify-send"
const PROMPT       = "@siebPrompt@"
const TERMINAL     = "@terminalBin@"
const EXEC_FLAG    = "@terminalExecFlag@"
const WORKDIR_FLAG = "@terminalWorkingDirFlag@"

# The emulator's name is also its app_id.
const TERMINAL_ID = "@terminalEmulator@"
const HELIUM_ID   = "helium"
# Popups that tile only by accident; their own scripts bring them back.
const SKIP = ["spotify_popup" "floating_shell" "sysmonitor"]

# Programs a restored terminal starts again; set in ironbar.nix.
def rerun-list []: nothing -> list<string> { '@rerun@' | from json }

def store-dir []: nothing -> string {
  $env.XDG_DATA_HOME? | default ($env.HOME | path join ".local/share") | path join "niri-workspaces"
}

def save-path [name: string]: nothing -> string {
  store-dir | path join $"($name).json"
}

def notify [title: string, body: string] {
  ^$NOTIFY_SEND -a workspaces $title $body | complete | ignore
}

def niri-json [what: string] {
  let r = (^niri msg -j $what | complete)
  if $r.exit_code == 0 { $r.stdout | from json } else { [] }
}

def focused-workspace [] {
  niri-json workspaces | where is_focused | get 0?
}

def proc-cwd [pid: int]: nothing -> string {
  $"/proc/($pid)/cwd" | path expand
}

def children [pid: int]: nothing -> list<int> {
  glob $"/proc/($pid)/task/*/children"
  | each {|f| open --raw $f }
  | str join " "
  | split row " "
  | where $it != ""
  | into int
}

# argv with the program by name rather than store path, which a rebuild
# would leave dangling. Nix wrappers exec `.foo-wrapped`; foo is the name.
def cmdline [pid: int]: nothing -> list<string> {
  let argv = (open --raw $"/proc/($pid)/cmdline" | split row (char nul) | where $it != "")
  if ($argv | is-empty) { return [] }
  $argv | update 0 {|a| $a | path basename | str replace -r '^\.(.*)-wrapped$' '$1' }
}

# A tile's share of the output, in percent. niri takes the gaps off before
# it applies a proportion, so a half-width column measures 49% or so;
# restoring that as is would shrink it a little on every save. Close enough
# to a usual preset, it snaps to it.
def width-percent [tile: number, output_width: number]: nothing -> float {
  let raw = ($tile / $output_width * 100)
  let near = ([25 33.333 50 66.667 75 100] | where {|p| ($p - $raw | math abs) <= 3 })
  if ($near | is-empty) { $raw | math round --precision 1 } else { $near | first | into float }
}

def entry [w: record, output_width: number]: nothing -> any {
  let pos = $w.layout.pos_in_scrolling_layout
  let base = {
    column: $pos.0
    row: $pos.1
    # As a share of the output, so a save made on one monitor fits another.
    width: (width-percent $w.layout.tile_size.0 $output_width)
    # Only for spotting tabbed columns; dropped before the save is written.
    height: $w.layout.tile_size.1
  }
  if $w.app_id == $TERMINAL_ID {
    # The shell is the terminal's only child, and what it runs is the
    # shell's; the prompt's directory is the shell's cwd.
    let shell = (children $w.pid | get 0?)
    if $shell == null { return ($base | merge {kind: "terminal", cwd: $env.HOME, run: null}) }
    let job = (children $shell | get 0?)
    let argv = (if $job == null { [] } else { cmdline $job })
    let run = (if ($argv | get 0? | default "") in (rerun-list) { $argv } else { null })
    $base | merge {kind: "terminal", cwd: (proc-cwd $shell), run: $run}
  } else if $w.app_id == $HELIUM_ID {
    $base | merge {kind: "browser"}
  } else {
    let argv = (cmdline $w.pid)
    if ($argv | is-empty) { return null }
    $base | merge {kind: "app", app_id: $w.app_id, pid: $w.pid, argv: $argv, cwd: (proc-cwd $w.pid)}
  }
}

# One line for the picker: terminal directories with what runs in them,
# then the rest by name.
def summary [windows: list]: nothing -> string {
  let dirs = ($windows | where kind == "terminal" | each {|t|
    let dir = ($t.cwd | path basename)
    if $t.run? == null { $dir } else { $"($dir) ($t.run.0)" }
  } | uniq)
  let rest = ($windows | where kind != "terminal" | each {|e|
    if $e.kind == "browser" { "helium" } else { $e.argv.0 }
  })
  $dirs | each {|d| $"\u{f120} ($d)" } | append $rest | str join ", "
}

def saves []: nothing -> list {
  let dir = (store-dir)
  if not ($dir | path exists) { return [] }
  glob ($dir | path join "*.json") | each {|f| open $f } | sort-by -r saved
}

# Saves the focused workspace under a name from the prompt. Returns the name
# and the workspace's id, or null when nothing was saved.
def save-workspace []: nothing -> any {
  let ws = (focused-workspace)
  if $ws == null { return null }

  let output = (niri-json outputs | get -o $ws.output | get -o logical)
  let output_width = ($output | get -o width | default 1920)
  let output_height = ($output | get -o height | default 1080)
  let windows = (niri-json windows
    | where workspace_id == $ws.id and (not $it.is_floating) and ($it.app_id? not-in $SKIP))
  let entries = ($windows | each {|w| entry $w $output_width } | compact)
  # niri's IPC does not say how a column is displayed, but the heights do:
  # stacked windows share the column's height, so none of several can reach
  # half of the output, while every tab gets all of it.
  let tabbed = ($entries | where row > 1 | get column | uniq | where {|c|
    ($entries | where column == $c | get height | math min) > ($output_height * 0.6)
  })
  let entries = ($entries
    | each {|e| $e | insert tabbed ($e.column in $tabbed) }
    | reject height)
  # Several windows of one process are one launch: the command opens them all.
  let entries = ($entries | where kind != "app"
    | append ($entries | where kind == "app" | uniq-by pid)
    | reject -o pid
    | sort-by column row)
  if ($entries | is-empty) {
    notify "Nothing to save" "The workspace has no tiled windows."
    return null
  }

  # The workspace's own name first, so Enter alone re-saves it.
  let names = ([$ws.name?] | append (saves | get name) | compact | uniq)
  let picked = ($names
    | str join "\n"
    | ^$PROMPT -p "Save as" --lines ([($names | length) 1] | math max | [$in 8] | math min) --badge (char --unicode f0c7)
    | complete)
  let name = ($picked.stdout | str trim | str replace -ra '[^A-Za-z0-9._-]+' '-')
  if $picked.exit_code != 0 or ($name | is-empty) { return null }

  mkdir (store-dir)
  {name: $name, saved: (date now | format date "%+"), summary: (summary $entries), windows: $entries}
  | to json
  | save -f (save-path $name)
  ^niri msg action set-workspace-name $name | complete | ignore
  notify $"Saved ($name)" (summary $entries)
  {name: $name, id: $ws.id}
}

def "main save" [] { save-workspace | ignore }

def "main close" [] {
  let saved = (save-workspace)
  if $saved == null { return }
  # Floating windows too: the workspace is going away, not just its layout.
  for w in (niri-json windows | where workspace_id == $saved.id) {
    ^niri msg action close-window --id $w.id | complete | ignore
  }
  # A named workspace outlives its windows; unnamed, niri drops it, and the
  # picker builds the save on a fresh one.
  ^niri msg action unset-workspace-name $saved.name | complete | ignore
}

# Spawns through niri so the window outlives this script, then waits for it
# to map: placing it needs its id, and the next one opens beside the
# focused column, so order only holds if each lands before the next spawns.
# `tries` at 100ms each; a browser starting cold needs more than a terminal.
def await-window [before: list, matches: closure, tries: int]: nothing -> any {
  for _ in 1..$tries {
    let new = (niri-json windows | where id not-in $before and (do $matches $it.app_id?))
    if ($new | is-not-empty) { return ($new | first | get id) }
    sleep 100ms
  }
  null
}

def place [workspace: string, e: record] {
  let launch = match $e.kind {
    "terminal" => {
      let cwd = (if ($e.cwd | path exists) { $e.cwd } else { $env.HOME })
      # nu -e runs the program and then stays, as if it was typed at the
      # prompt. Arguments go through nuon so spaces and quotes survive.
      let run = (if $e.run? == null { [] } else {
        let line = ($e.run | skip 1 | each { to nuon } | prepend $"^($e.run.0)" | str join " ")
        [$EXEC_FLAG "nu" "-e" $line]
      })
      {argv: [$TERMINAL $WORKDIR_FLAG $cwd ...$run], matches: {|a| $a == $TERMINAL_ID }, tries: 100}
    }
    "browser" => {
      argv: [$HELIUM "--ozone-platform=wayland" "--new-window"]
      matches: {|a| $a == $HELIUM_ID }
      tries: 300
    }
    _ => {
      # Gone since the save, or never on PATH: waiting for it would only stall.
      if (which $e.argv.0 | is-empty) { return }
      let app_id = $e.app_id
      {argv: [$ENV_BIN "-C" $e.cwd ...$e.argv], matches: {|a| $a == $app_id }, tries: 100}
    }
  }

  # New windows open on the focused workspace, and a restore takes a few
  # seconds; looking elsewhere meanwhile must not scatter the rest.
  ^niri msg action focus-workspace $workspace | complete | ignore
  let before = (niri-json windows | get id)
  ^niri msg action spawn -- ...$launch.argv | complete | ignore
  let id = (await-window $before $launch.matches $launch.tries)
  if $id == null { return }

  ^niri msg action focus-window --id $id | complete | ignore
  if $e.row > 1 {
    # It opened as a column of its own; fold it under the one to its left.
    ^niri msg action consume-or-expel-window-left --id $id | complete | ignore
  } else {
    ^niri msg action set-column-width $"($e.width)%" | complete | ignore
    # Before the rest of the column joins, so they come in as tabs.
    if $e.tabbed? == true {
      ^niri msg action set-column-display tabbed | complete | ignore
    }
  }
}

def "main restore" [name: string] {
  let file = (save-path $name)
  if not ($file | path exists) {
    notify "No such workspace" $name
    return
  }

  let named = (niri-json workspaces | where name? == $name | get 0?)
  if $named != null {
    ^niri msg action focus-workspace $name | complete | ignore
    # Restored already and still populated: being there is the whole point.
    if (niri-json windows | where workspace_id == $named.id | is-not-empty) { return }
  }

  # `place` refocuses the workspace before every spawn, which takes a name;
  # one the workspace has already is kept.
  let ws = (focused-workspace)
  let workspace = ($ws.name? | default $name)
  if $ws.name? == null {
    ^niri msg action set-workspace-name $name | complete | ignore
  }
  # New windows open right of the focused column, so starting from the last
  # one puts the save after whatever is there.
  if (niri-json windows | where workspace_id == $ws.id | is-not-empty) {
    ^niri msg action focus-column-last | complete | ignore
  }

  for e in (open $file | get windows | sort-by column row) { place $workspace $e }
}

def main [] {
  let all = (saves)
  if ($all | is-empty) {
    notify "No saved workspaces" "Save the focused one first."
    return
  }

  let picked = ($all
    | each {|s| {name: $s.name, label: $"($s.name)    ($s.summary)"} | to json --raw }
    | str join "\n"
    | ^$PROMPT -p "Workspace" --text label --lines ([($all | length) 10] | math min) --badge (char --unicode f2d2)
    | complete)
  if $picked.exit_code != 0 { return }
  main restore ($picked.stdout | from json | get name)
}
