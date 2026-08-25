#!@nu@/bin/nu -n

# Application list and launcher, replacing `rofi -show drun`.
#
# rofi's drun mode is doing three things: enumerate .desktop files across the
# XDG data dirs, filter them, and launch the winner. Only the first and third
# need to live here; the filtering happens in the widget so the list narrows as
# you type without a round trip.
#
# Deliberately dropped: rofi's other modi (run, ssh, window). The launcher is
# only ever used to start applications, so the mode-switcher row at the bottom
# of the rofi window has no reason to exist here.
#
# Not replicated: rofi sorts by usage history, which is why its list opens on
# recently-used apps rather than alphabetically. This sorts by name. Frecency
# would mean keeping a counter file and is a separate piece of work.

# XDG precedence: XDG_DATA_HOME first, then XDG_DATA_DIRS in order. The first
# file for a given desktop id wins, which is how a user override in
# ~/.local/share/applications shadows the system one.
def app-dirs []: nothing -> list<string> {
  let home = ($env.XDG_DATA_HOME? | default $"($env.HOME)/.local/share")
  let dirs = ($env.XDG_DATA_DIRS? | default "/usr/local/share:/usr/share" | split row ":")
  ([$home] ++ $dirs)
  | each {|d| $"($d)/applications" }
  | where {|d| $d | path exists }
}

# A .desktop file is INI-ish. Only the [Desktop Entry] group matters; later
# groups are per-action ([Desktop Action new-window] and friends). Keys with a
# locale suffix (Name[de]=…) are skipped so the unlocalised value wins.
def parse-desktop [file: string]: nothing -> record {
  mut in_entry = false
  mut rec = {}
  for line in (open --raw $file | decode utf-8 | lines) {
    let l = ($line | str trim)
    if ($l | str starts-with "[") {
      $in_entry = ($l == "[Desktop Entry]")
      continue
    }
    if (not $in_entry) or (not ($l | str contains "=")) or ($l | str starts-with "#") {
      continue
    }
    let parts = ($l | split row "=")
    let k = ($parts | first | str trim)
    if ($k | str contains "[") { continue }
    $rec = ($rec | upsert $k (($parts | skip 1 | str join "=") | str trim))
  }
  $rec
}

# Field codes are placeholders for files and URIs the launcher would pass in.
# Nothing is being passed, so they are stripped rather than substituted.
def clean-exec [exec: string]: nothing -> string {
  $exec
  | str replace --all --regex '%[fFuUdDnNickvm]' ''
  | str replace --all '%%' '%'
  | str trim
}

def apps []: nothing -> list {
  app-dirs
  | each {|d| ls --short-names $d | where name =~ '\.desktop$' | each {|f| {id: $f.name, path: ($d | path join $f.name)} } }
  | flatten
  | uniq-by id
  | each {|f|
      let e = (parse-desktop $f.path)
      {
        id: $f.id
        name: ($e.Name? | default "")
        comment: ($e.Comment? | default "")
        exec: (clean-exec ($e.Exec? | default ""))
        terminal: (($e.Terminal? | default "false") == "true")
        show: ((($e.Type? | default "") == "Application")
               and (($e.NoDisplay? | default "false") != "true")
               and (($e.Hidden? | default "false") != "true")
               and (($e.Name? | default "") != "")
               and (($e.Exec? | default "") != ""))
      }
    }
  | where show
  | sort-by {|a| $a.name | str lowercase }
}

# The match rule, kept identical to the jq filter in widgets/launcher.yuck.
# If the two disagree, the highlighted row stops being the row Enter runs.
def matches [app: record, q: string]: nothing -> bool {
  if ($q | str trim | is-empty) { return true }
  let needle = ($q | str lowercase)
  # One line, deliberately: nushell ends the expression at the newline, so a
  # leading `or` on the next line parses as a command name, not a continuation.
  ((($app.name | str lowercase) | str contains $needle) or (($app.comment | str lowercase) | str contains $needle))
}

def main [] {
  apps | to json --raw | print
}

def "main list" [] {
  apps | to json --raw | print
}

def launch-app [app: record] {
  let dir = ($env.FILE_PWD | path dirname)
  ^@eww@/bin/eww -c $dir update query="" | complete | ignore
  ^@eww@/bin/eww -c $dir close launcher | complete | ignore

  # Nushell has no `&`, so detaching goes through setsid, the same way the
  # waybar helpers in this config do it. sh -c because Exec is a shell-ish
  # string with its own quoting.
  let cmd = if $app.terminal {
    # TODO: wire to config.terminal.bin / execFlag when this moves into nix.
    let term = ($env.TERMINAL? | default "kitty")
    $"($term) -e ($app.exec)"
  } else {
    $app.exec
  }
  ^@utilLinux@/bin/setsid --fork sh -c $cmd | complete | ignore
}

def "main launch" [id: string] {
  let app = (apps | where id == $id | get 0?)
  if $app == null { return }
  launch-app $app
}

# Enter in the search box: resolve the query the same way the widget does and
# launch the top hit. An empty or unmatched query does nothing, which is what
# keeps a stray Enter harmless.
# Dry run of the same resolution, for checking that this file and the jq
# filter in launcher.yuck still agree. Prints, launches nothing.
def "main match" [query: string] {
  let hit = (apps | where {|a| matches $a $query } | get 0?)
  print (if $hit == null { "(none)" } else { $hit.name })
}

def "main launch-match" [query: string] {
  let hit = (apps | where {|a| matches $a $query } | get 0?)
  if $hit == null { return }
  if ($query | str trim | is-empty) { return }
  launch-app $hit
}
