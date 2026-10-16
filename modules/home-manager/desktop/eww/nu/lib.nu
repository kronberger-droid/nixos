# Process helpers shared by the scripts here, which `use` this file by its store
# path. Not a script itself: no shebang and no `main`, and eww.nix builds it on
# its own rather than installing it under scripts/.

# Binaries by store path; see eww.nix for why these are consts and not
# spelled inline at the call sites.
const SETSID          = "@utilLinux@/bin/setsid"
const TERMINAL        = "@terminalBin@"
const TERM_APPID_FLAG = "@terminalAppIdFlag@"
const TERM_EXEC_FLAG  = "@terminalExecFlag@"

# Runs `cmd` in a session of its own and returns at once. Nushell has no `&`,
# and its `job spawn` runs in a thread of *this* process, so anything started
# that way would die when the script exits.
#
# eww kills an onclick handler that outlives the widget's :timeout, 200ms by
# default, which is what the "command ... timed out" lines in the journal are;
# anything that waits on a menu session has to leave the process tree first.
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
