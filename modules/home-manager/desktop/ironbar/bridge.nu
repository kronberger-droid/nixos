#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# Runs one of eww's status scripts and feeds its JSON into ironbar.
#
# The eww scripts print `{text, tooltip, class}` records. Ironbar has no JSON
# input: a watch-mode label shows the last stdout line as is, CSS classes are
# fixed in the config, and only ironvars and `ironbar style` change at runtime.
# So this splits each record three ways:
#
#   text     printed, for the `{{watch:…}}` label that started this
#   tooltip  the `<name>_tip` ironvar, which the module's `tooltip` reads
#   class    swapped on the module named <name> with remove-class/add-class
#
# plus `<name>_shown`, true while text is non-empty, for `show_if` on modules
# that should vanish when idle (screenrec, mpris).
#
# Always a watch process, even for scripts eww polled: the class swap needs
# the previous class, and a process that lives across polls can just keep it.
#
#   bridge <name> <seconds> <script> [args...]   poll every <seconds>
#   bridge <name> listen <script> [args...]      script streams JSON lines

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const IRONBAR = "@ironbar@/bin/ironbar"

# Pushes one record and returns its class, the `prev` for the next one.
def push [name: string, prev: string, line: string]: nothing -> string {
  let r = (try { $line | from json } catch { null })
  if $r == null { return $prev }

  # audio.nu's record carries vol and suffix where the others have text, and
  # eww hid the number while muted. Unpadded: eww's padnum pads to three, but
  # eww labels unindent by default, so the padding never reached the screen.
  let text = if ($r.vol? != null) {
    let vol = if ($r.muted? | default false) { "" } else { $r.vol | into string }
    $"($vol)($r.suffix? | default "")"
  } else {
    $r.text? | default ""
  }
  let cls = ($r.class? | default "")
  ^$IRONBAR var set $"($name)_tip" ($r.tooltip? | default "") | complete | ignore
  ^$IRONBAR var set $"($name)_shown" ($text | is-not-empty | into string) | complete | ignore
  if $cls != $prev {
    if ($prev | is-not-empty) { ^$IRONBAR style remove-class $name $prev | complete | ignore }
    if ($cls | is-not-empty) { ^$IRONBAR style add-class $name $cls | complete | ignore }
  }
  print $text
  $cls
}

def main [name: string, every: string, script: string, ...args: string] {
  if $every == "listen" {
    ^$script ...$args | lines | reduce --fold "" {|line, prev| push $name $prev $line } | ignore
    return
  }

  let pause = ($every | into int | into duration --unit sec)
  mut prev = ""
  loop {
    let out = (^$script ...$args | complete)
    if $out.exit_code == 0 {
      $prev = (push $name $prev ($out.stdout | str trim))
    }
    sleep $pause
  }
}
