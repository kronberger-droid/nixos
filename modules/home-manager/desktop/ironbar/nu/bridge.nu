#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Feeds the status scripts' JSON records into ironbar.
#
# The scripts print `{text, tooltip, class}` records. Ironbar has no JSON
# input: CSS classes are fixed in the config, and only ironvars and `ironbar
# style` change at runtime. So a record is split:
#
#   text     the `<name>_text` ironvar, which the module's label reads
#   tooltip  the `<name>_tip` ironvar, which its tooltip reads
#   class    swapped on the module named <name>
#
# plus `<name>_shown`, for `show_if` on modules that vanish when idle
# (screenrec, mpris).
#
#   bridge poll <name> <script> [args...]     run a status script once and
#                                             push what it prints; the bar's
#                                             `{{ms:…}}` polls are this
#   bridge listen <name> <script> [args...]   a script streaming records
#   bridge push <name> <json>                 one record, from a toggle's
#                                             refresh
#
# `poll` prints nothing and `listen` an empty line per record, so the labels
# running them show only their ironvars.

use "@barLib@" *

def runtime []: nothing -> string { $env.XDG_RUNTIME_DIR? | default "/tmp" }

# What ironbar was last told about <name>, so an unchanged record costs one
# IPC call instead of seven. Only trusted when written after ironbar's IPC
# socket was: a restarted bar starts again from its ironvar defaults, and
# then everything is pushed in full.
def cached [name: string]: nothing -> any {
  let file = (runtime | path join $"bar-($name).json")
  let sock = (runtime | path join "ironbar-ipc.sock")
  if not ($file | path exists) or not ($sock | path exists) { return null }
  if (ls $file | get 0.modified) <= (ls $sock | get 0.modified) { return null }
  try { open $file } catch { null }
}

def "main push" [name: string, json: string] {
  let r = (try { $json | from json } catch { null })
  if $r == null { return }

  let text = ($r.text? | default "")
  let next = {
    text: $text
    tip: ($r.tooltip? | default "")
    shown: ($text | is-not-empty | into string)
    class: ($r.class? | default "")
  }
  let prev = (cached $name | default {text: null, tip: null, shown: null, class: ""})

  for k in [text tip shown] {
    let v = ($next | get $k)
    if ($prev | get $k) != $v { set-var $"($name)_($k)" $v }
  }
  if ($prev.class | is-not-empty) and $prev.class != $next.class {
    style remove-class $name $prev.class
  }
  # Every time, changed or not: ironvars outlive `ironbar reload` but the
  # rebuilt widgets come up classless.
  if ($next.class | is-not-empty) { style add-class $name $next.class }

  $next | to json --raw | save -f (runtime | path join $"bar-($name).json")
}

def "main poll" [name: string, script: string, ...args: string] {
  let out = (^$script ...$args | complete)
  if $out.exit_code == 0 { main push $name ($out.stdout | str trim) }
}

def "main listen" [name: string, script: string, ...args: string] {
  ^$script ...$args | lines | each {|line|
    main push $name $line
    print ""
  } | ignore
}

def main [] {
  print "usage: bridge (poll | listen) <name> <script> [args...], bridge push <name> <json>"
}
