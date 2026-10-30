#!@coreutils@/bin/env -S @nu@/bin/nu -n --no-std-lib

# The launcher's one mode: sieb's drun, with typed prefixes in place of the
# run, files and window tabs.
#
#   p: <command>   runs it detached, like dmenu
#   nu: <expr>     evaluates it and lists the result
#
# Once a result is listed, typing no longer filters it (sieb's
# `no-filter`; matching rows are only highlighted):
#
#   | <command>    pipes the whole result on: `$history.N | <command>`
#   fz: <query>    keeps the rows that fuzzy-match, best first, as sieb
#                  ranks them
#   rg: <regex>    keeps the rows whose text matches, in order
#   Enter with nothing typed narrows to the highlighted entry, which the
#                  next `|` then gets
#   Ctrl+Enter     copies the row
#   Tab            puts in the next completion of what is typed, from
#                  `nu --ide-complete` (sieb's `complete`), also for `nu:`
#                  in the app list
#   anything else  is a fresh expression, as at a prompt
#
# Evaluation happens in a long-running `nu --mcp`, reached over a socket
# (the nu-mcp units in sieb.nix). Its MCP session keeps every result in
# `$history`, so this script holds no state: the session id and the listed
# result's history index ride along in sieb's `data` field. A `nu:` from
# the app list opens a fresh session; nu drops idle ones after 30 minutes.
#
# Anything outside a result list, and every call that is not typed text,
# goes to drun.nu untouched. sieb calls scripts on Enter, not per
# keystroke, so a prefix acts once the line is accepted.

# Binaries by store path, as consts; see ironbar.nix for why.
const DRUN    = "@drun@"
const SIEB    = "@sieb@/bin/sieb"
const NU      = "@nu@/bin/nu"
const SETSID  = "@utilLinux@/bin/setsid"
const WL_COPY = "@wlClipboard@/bin/wl-copy"

const SOCKET = "@nuSocket@"
# The socket stands in for the host; nu checks it is a loopback one.
const URL = "http://localhost/mcp"
# Past this a list is cut; sieb would only be scrolling through it.
const MAX_ROWS = 5000

# A menu option in rofi's in-band form.
def option [key: string, value: string] {
  print $"\u{0}($key)\u{1f}($value)"
}

# Its own session and no stdout, so sieb sees the script end and closes.
def detach [command: string] {
  cd $env.HOME
  ^$SETSID -f sh -c $command o+e> /dev/null
}

# One JSON-RPC message to the MCP server. Replies come as server-sent
# events; the message is the last `data:` line.
def rpc [body: record, session?: string]: nothing -> record {
  let headers = ({Accept: "application/json, text/event-stream"}
    | if $session == null { $in } else { insert mcp-session-id $session })
  let response = (http post --full --allow-errors
    --unix-socket ($env.XDG_RUNTIME_DIR | path join $SOCKET)
    --content-type application/json --headers $headers $URL $body)
  let messages = ($response.body | lines
    | where ($it | str starts-with "data: ")
    | each { str substring 6.. }
    | where ($it | is-not-empty))
  {
    status: $response.status
    session: ($response.headers.response | where name == mcp-session-id | get 0?.value?)
    message: (if ($messages | is-empty) { null } else { $messages | last | from json })
  }
}

# A new MCP session, or null when nu-mcp cannot be reached; `evaluate`
# turns that into the message.
def open-session []: nothing -> any {
  let init = (try {
    rpc {jsonrpc: "2.0", id: 1, method: initialize, params: {
      protocolVersion: "2025-03-26"
      capabilities: {}
      clientInfo: {name: sieb-launcher, version: "1"}
    }}
  } catch { return null })
  if $init.session == null { return null }
  rpc {jsonrpc: "2.0", method: "notifications/initialized"} $init.session | ignore
  $init.session
}

# The evaluate result in `session`, or a record with `error`.
def evaluate [session: any, source: string]: nothing -> record {
  if $session == null { return {error: "nu-mcp not reachable", help: "systemctl --user status nu-mcp"} }
  let reply = (try {
    rpc {jsonrpc: "2.0", id: 2, method: tools/call, params: {name: evaluate, arguments: {input: $source}}} $session
  } catch {
    return {error: "nu-mcp not reachable", help: "systemctl --user status nu-mcp"}
  })
  if $reply.status == 404 { return {error: "session expired", help: "start again with nu:"} }
  let result = ($reply.message?.result? | default {})
  let structured = ($result.structuredContent? | default {})
  if $result.isError? == true or $reply.message?.error? != null {
    return {error: ($structured.msg? | default ($reply.message?.error?.message? | default "failed")), help: $structured.help?}
  }
  $structured
}

# The rows a value is listed as: a table by its `name` column where it has
# one, a record as `key: value`, text by its lines. Each row's index rides
# along as its info, which `narrow` reads back.
def rows [value: any]: nothing -> list<string> {
  let type = ($value | describe)
  if ($type | str starts-with "table") or ($type | str starts-with "list") {
    $value | first $MAX_ROWS | each {|item|
      if ($item | describe | str starts-with "record") {
        $item.name? | default ($item | to nuon)
      } else {
        $item | to text
      }
    }
  } else if ($type | str starts-with "record") {
    $value | transpose key value | each {|r| $"($r.key): ($r.value | to nuon)" }
  } else {
    $value | to text | lines | first $MAX_ROWS
  }
}

# What the rows were cut from, for the message line.
def shape [value: any]: nothing -> string {
  let type = ($value | describe)
  if ($type | str starts-with "table") or ($type | str starts-with "list") {
    $"($value | length) rows"
  } else if ($type | str starts-with "record") {
    $"($value | columns | length) fields"
  } else if ($type | str starts-with "string") {
    $"($value | lines | length) lines"
  } else {
    $type
  }
}

# Lists a result. On an error the previous result stays listed with the
# error above it, so a typo does not lose the list.
def show [session: any, result: record, previous: any] {
  option prompt nu
  option complete "true"
  # The list stays as listed while typing, matches only highlighted, and
  # Enter with text typed runs the text rather than picking a row.
  option no-filter "true"
  if "error" in $result {
    let help = ($result.help? | default "")
    let message = (if ($help | is-empty) { $result.error } else { $"($result.error) \(($help)\)" })
    if $previous == null {
      option data $"nu:($session | default ''):"
      option message $message
      return
    }
    let again = (evaluate $session $"$history.($previous)")
    option data $"nu:($session):($again.history_index? | default $previous)"
    option message $message
    list ($again.output? | default [])
    return
  }
  option data $"nu:($session):($result.history_index)"
  option message $"$history.($result.history_index) · (shape $result.output)"
  list $result.output
}

# The rows as shown: a newline would end one early, and NUL and US would
# break the framing.
def texts [value: any]: nothing -> list<string> {
  rows $value | each { str replace -ra "[\n\r\u{0}\u{1f}]" " " }
}

def list [value: any] {
  texts $value | enumerate | each {|row|
    print $"($row.item)\u{0}info\u{1f}($row.index)"
  } | ignore
}

# The listed entry by itself, the way it was shown: an `ls` row is its path.
def narrow [index: int, row: int]: nothing -> string {
  $"do {|v, i|
    let type = \($v | describe\)
    if \($type | str starts-with 'table'\) or \($type | str starts-with 'list'\) {
      let item = \($v | get $i\)
      if \($item | describe | str starts-with 'record'\) and \('name' in \($item | columns\)\) { $item.name } else { $item }
    } else if \($type | str starts-with 'record'\) {
      $v | values | get $i
    } else {
      $v | to text | lines | get $i
    }
  } $history.($index) ($row)"
}

# nu-mcp collects a result item by item and keeps a lone item bare, so a
# one-row table would come back as a record. In an outer one-item list, the
# bare item is the value itself. Not for `nu:` as typed, whose `let`s would
# end at the parentheses.
def keep [source: string]: nothing -> string {
  $"[\(($source)\)]"
}

# Source that keeps the entries behind rows `wanted` of `$history.(index)`,
# in that order, with the shape they were listed from.
def pick [index: int, wanted: list<int>]: nothing -> string {
  $"do {|v, wanted|
    let type = \($v | describe\)
    if \($type | str starts-with 'table'\) or \($type | str starts-with 'list'\) {
      $wanted | each {|i| $v | get $i }
    } else if \($type | str starts-with 'record'\) {
      let keys = \($v | columns\)
      $v | select ...\($wanted | each {|i| $keys | get $i }\)
    } else {
      let lines = \($v | to text | lines\)
      $wanted | each {|i| $lines | get $i }
    }
  } $history.($index) ($wanted | to nuon)"
}

# `fz:` and `rg:`: the listed rows that match, as a new result.
def filter [session: any, index: int, how: string, pattern: string]: nothing -> record {
  let listed = (evaluate $session $"$history.($index)")
  if "error" in $listed { return $listed }
  let shown = (texts $listed.output)
  let wanted = (if $how == "fz" {
    # sieb's own matcher, so this ranks like the app list does. No match
    # exits 1 with nothing printed.
    $shown | str join "\n" | ^$SIEB -f $pattern --index | complete | get stdout | lines | into int
  } else {
    try {
      $shown | enumerate | where {|row| $row.item =~ $pattern } | get index
    } catch {
      return {error: $"not a regex: ($pattern)"}
    }
  })
  evaluate $session (keep (pick $listed.history_index $wanted))
}

# The longest tail of `typed` that `completion` starts with, beginning at
# a word: what the completion replaces. `nu --ide-complete` names the
# completion but not the span it is for.
def replaced [typed: string, completion: string]: nothing -> int {
  let length = ($typed | str length)
  for k in ($length..1) {
    let tail = ($typed | str substring ($length - $k)..)
    let before = (if $k == $length { " " } else { $typed | str substring ($length - $k - 1)..($length - $k - 1) })
    if ($completion | str starts-with $tail) and ($before in [" " "|" "(" "[" "{" ";"]) {
      return $k
    }
  }
  0
}

# Completions of the typed line, for sieb's `complete` call: rows with the
# completion as their text and the whole line it makes as their info.
def completions [typed: string, listed: bool] {
  # What stays in front of the nu source, and the nu source itself.
  let split = (if ($typed | str starts-with "nu:") {
    $typed | parse -r '^(?<keep>nu:\s*)(?<source>.*)$' | get 0
  } else if ($typed =~ '^(p|fz|rg):') or (not $listed) {
    return
  } else {
    {keep: "", source: $typed}
  })
  if ($split.source | is-empty) { return }
  # A pipe needs something to pipe from for nu to parse the rest.
  let lead = (if ($split.source | str starts-with "|") { "[] " } else { "" })
  let file = ($env.XDG_RUNTIME_DIR | path join "sieb-complete.nu")
  $"($lead)($split.source)" | save -f $file
  let offset = ($"($lead)($split.source)" | str length)
  let found = (try {
    ^$NU -n --ide-complete $offset $file | from json | get completions
  } catch { [] })
  rm -f $file
  $found | first 8 | each {|completion|
    let k = (replaced $split.source $completion)
    if $k > 0 or ($split.source | str ends-with " ") {
      let source = ($split.source | str substring 0..<(($split.source | str length) - $k))
      print $"($completion)\u{0}info\u{1f}($split.keep)($source)($completion)"
    }
  } | ignore
}

def main [choice?: string] {
  let retv = ($env.ROFI_RETV? | default "0")

  if $retv == "20" {
    completions ($choice | default "") (($env.ROFI_DATA? | default "") | str starts-with "nu:")
    return
  }
  # `nu:<session>:<index>` while a result is listed; the index is empty
  # after a first expression failed.
  let listed = ($env.ROFI_DATA? | default "" | parse -r '^nu:(?<session>[^:]*):(?<index>\d*)$' | get 0?)
  let session = (if $listed == null or ($listed.session | is-empty) { null } else { $listed.session })
  let current = (if $listed == null or ($listed.index | is-empty) { null } else { $listed.index | into int })

  if $listed != null and $current != null {
    match $retv {
      "1" => { show $session (evaluate $session (keep (narrow $current ($env.ROFI_INFO | into int)))) $current; return }
      "10" => { $choice | ^$WL_COPY; return }
      _ => {}
    }
  }

  if $retv == "2" and $choice != null {
    let typed = ($choice | parse -r '^(?<prefix>p|nu|fz|rg):\s*(?<rest>.*)$' | get 0?)
    match ($typed | get -o prefix) {
      "p" => { detach $typed.rest; return }
      "fz" | "rg" if $current != null => {
        show $session (filter $session $current $typed.prefix $typed.rest) $current
        return
      }
      "fz" | "rg" => {
        show null {error: $"($typed.prefix): filters a listed result", help: "list one with nu: first"} null
        return
      }
      "nu" => {
        # From the app list a new session, so `$history` starts empty.
        let session = (if $listed == null { open-session } else { $session })
        show $session (evaluate $session $typed.rest) $current
        return
      }
      _ => {}
    }
    if $listed != null {
      let source = (if ($choice | str starts-with "|") and $current != null {
        keep $"$history.($current) ($choice)"
      } else {
        $choice
      })
      let session = ($session | default (open-session))
      show $session (evaluate $session $source) $current
      return
    }
  }

  # The app list too, so a `nu:` typed there completes.
  if $retv == "0" { option complete "true" }
  ^$NU $DRUN ...([$choice] | compact)
}
