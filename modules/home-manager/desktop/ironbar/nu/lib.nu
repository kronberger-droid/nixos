# Helpers shared by the scripts here, which `use` this file by its store
# path. Not a script itself: no shebang and no `main`, and ironbar.nix builds it
# on its own rather than installing it under scripts/.

# Binaries by store path; see ironbar.nix for why these are consts and not
# spelled inline at the call sites.
const SETSID          = "@utilLinux@/bin/setsid"
const TERMINAL        = "@terminalBin@"
const TERM_APPID_FLAG = "@terminalAppIdFlag@"
const TERM_EXEC_FLAG  = "@terminalExecFlag@"
const IRONBAR         = "@ironbar@/bin/ironbar"

# Runs `cmd` in a session of its own and returns at once. Nushell has no `&`,
# and its `job spawn` runs in a thread of *this* process, so anything started
# that way would die when the script exits.
#
# A bar's click handler is no place for a long-lived child: eww killed any that
# outlived the widget's 200ms :timeout (the "command ... timed out" lines in
# old journals), and anything that waits on a menu session should leave the
# bar's process tree first regardless.
#
# The redirects, not `| complete | ignore`, are what does the leaving. `complete`
# waits for EOF on the pipe rather than for the process, and the detached
# grandchild inherits the write end, so it blocks for as long as the thing it
# just detached from stays alive: measured at the full two minutes for a
# `setsid --fork sleep 120`. Fresh descriptors return in 11ms instead.
#
# A literal `-f` among the arguments would be parsed as a flag to `detach` and
# fail at parse time, so callers with flags spread them in as one list. Spread
# values are not reinterpreted.
export def detach [...cmd: string] {
  ^$SETSID -f ...$cmd out> /dev/null err> /dev/null
}

# Opens config.terminal.bin with the given app-id running `cmd`, detached as
# above. The app-id is what niri's window rules and the toggles' window lookups
# match on.
export def spawn-terminal [app_id: string, ...cmd: string] {
  detach $TERMINAL $TERM_APPID_FLAG $app_id $TERM_EXEC_FLAG ...$cmd
}

# Ironbar's runtime variables, one IPC call each. An unset or unreachable
# variable reads as "", which every caller treats as false or empty.
export def get-var [key: string]: nothing -> string {
  let r = (^$IRONBAR var get $key | complete)
  if $r.exit_code == 0 { $r.stdout | str trim } else { "" }
}

export def set-var [key: string, value: string] {
  ^$IRONBAR var set $key $value | complete | ignore
}

# `ironbar style add-class`/`remove-class` on the module called `module`.
export def style [op: string, module: string, class: string] {
  ^$IRONBAR style $op $module $class | complete | ignore
}
