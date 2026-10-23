#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Feeds the status scripts' JSON records into ironbar.
#
# The scripts print `{text, tooltip, class}` records, as they did for eww.
# Ironbar has no JSON input: CSS classes are fixed in the config, and only
# ironvars and `ironbar style` change at runtime. So a record is split:
#
#   text     the `<name>_text` ironvar, which the module's label reads
#   tooltip  the `<name>_tip` ironvar, which its tooltip reads
#   class    swapped on the module named <name>, remembered in `<name>_class`
#
# plus `<name>_shown`, for `show_if` on modules that vanish when idle or
# absent (screenrec, mpris, battery, backlight).
#
#   bridge push <name> <json>                 one record, from a script's
#                                             `push` or a toggle's refresh
#   bridge listen <name> <script> [args...]   a script streaming records
#
# `listen` runs as a `{{watch:…}}` label script and prints an empty line per
# record, so the label shows only its ironvar.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const IRONBAR = "@ironbar@/bin/ironbar"

def set-var [key: string, value: string] {
  ^$IRONBAR var set $key $value | complete | ignore
}

def get-var [key: string]: nothing -> string {
  let r = (^$IRONBAR var get $key | complete)
  if $r.exit_code == 0 { $r.stdout | str trim } else { "" }
}

# audio, backlight and battery carry the number and its glyph tail as
# separate fields (`vol`/`pct` and `suffix`), as eww's widgets padded the
# number themselves. Unpadded here: eww labels unindent by default, so that
# padding never reached the screen either. Audio hides the number while
# muted, as waybar's format-muted did.
def text-of [r: record]: nothing -> string {
  let n = ($r.vol? | default $r.pct?)
  if $n == null { return ($r.text? | default "") }
  let num = if ($r.muted? | default false) { "" } else { $n | into string }
  $"($num)($r.suffix? | default "")"
}

def "main push" [name: string, json: string] {
  let r = (try { $json | from json } catch { null })
  if $r == null { return }

  let text = (text-of $r)
  set-var $"($name)_text" $text
  set-var $"($name)_tip" ($r.tooltip? | default "")
  set-var $"($name)_shown" (($text | is-not-empty) and ($r.present? | default true) | into string)

  # Unconditional, never skipped when the class is unchanged: ironvars
  # outlive `ironbar reload` but the rebuilt widgets come up classless, so
  # the stored class is only a record of what to remove.
  let cls = ($r.class? | default "")
  let prev = (get-var $"($name)_class")
  if ($prev | is-not-empty) { ^$IRONBAR style remove-class $name $prev | complete | ignore }
  if ($cls | is-not-empty) { ^$IRONBAR style add-class $name $cls | complete | ignore }
  set-var $"($name)_class" $cls
}

def "main listen" [name: string, script: string, ...args: string] {
  ^$script ...$args | lines | each {|line|
    main push $name $line
    print ""
  } | ignore
}

def main [] {
  print "usage: bridge (push <name> <json> | listen <name> <script> [args...])"
}
