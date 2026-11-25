#!/usr/bin/env nu
# Bitwarden through rbw, after rofi-rbw. Run by the sieb-rbw wrapper in
# ../sieb.nix. It began as the rbw example sieb used to ship.
#
# The wrapper unlocks first. A locked vault makes rbw ask for the master
# password, and that prompt would open while sieb holds the keyboard. With sieb-pinentry
# as rbw's pinentry, the unlock is a sieb panel of its own. The menus only
# read what rbw already has unlocked, and the actions run once sieb has
# closed, so the only call that could prompt is the list, as sieb opens.
# Should the vault lock in that moment, sieb-pinentry shows that it lacks
# the keyboard instead of taking a password typed into the picker.
#
# Enter on a login types its username, Tab and password into the window
# sieb was opened over. ENTRY_KEYS copy or type one of its fields straight
# from the list, as rofi-rbw's do. Ctrl+Enter (ROFI_RETV 10) lists the
# entry's fields instead, and so does Enter on a note, card, identity or
# SSH key. There, Enter queues a field and goes back to the entries, so a
# form can be filled from the username of one entry and the password of
# another; Ctrl+Enter types the field right away and FIELD_KEYS copy it.
# Once something is queued, a row on top of the entries types the queue in
# order, Tab between the fields. The keys are sieb's `custom-keys`.
#
# Notes are shown in full under the fields, and can be copied.
#
# The entry last used is remembered, so that a login whose fields go into
# places Tab does not connect takes one short visit per field. After a
# field was typed or copied from the field list, sieb opens on that list
# again with the field selected; after anything else, on the entries with
# the entry selected. Only the entry's id, name and type and the field's
# name are kept, in $XDG_RUNTIME_DIR, and not at all without one. It
# should last as long as the unlock, which the script cannot see ending:
# the wrapper sets RBW_PICKER_FRESH when it had to unlock the vault.
#
# Alt+s on the entries runs `rbw sync` and lists them again.
#
# Nothing here edits. `rbw edit` (1.15.0) re-encrypts with the account key
# and leaves an entry's own item key out of the update, so the server
# drops it and the entry's name, username and TOTP can no longer be
# decrypted by any client (doy/rbw#364). It also drops passkeys. Edit in
# the official clients until rbw ships a fix (doy/rbw#368).
#
# sieb holds the keyboard while it is open, so typing waits until it has
# closed and focus is back, and copies clear themselves. Needs rbw, wtype,
# wl-clipboard and notify-send.
#
# The secrets never pass through this script. The field list comes from
# `rbw get --list-fields`, which prints names only, and the only values
# read for display are those in SHOWN. Each action is a small sh program
# that asks rbw itself and pipes the answer straight into wtype or
# wl-copy, so no password lands in nu's memory or in anyone's argv. Only
# entry ids and field names are passed along, and the queue rides between
# calls in sieb's `data`.

# Seconds for focus to return to the window sieb was opened over.
const TYPE_DELAY = 1
# Milliseconds between typed keys. Some apps drop keys typed faster.
const KEY_DELAY = 12
# Seconds before a copied secret is cleared, if it is still the clipboard.
const CLEAR_AFTER = 30

# Fields whose values are shown next to their names. The rest show their
# name alone, since a password, TOTP seed, card number or a hidden custom
# field must not be read here.
const SHOWN = ["username" "uris" "email" "notes"]

const GLYPHS = {
    username: "\u{f007}"
    password: "\u{f084}"
    totp: "\u{f017}"
    uris: "\u{f0c1}"
    notes: "\u{f249}"
}
const GLYPH_OTHER = "\u{f02b}"

# What rbw calls an entry id. Anything else in `info` or `data` did not come
# from this script, and is never handed to `rbw get`, which would match it
# as a name or URI against the whole vault.
const UUID = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# sieb's JSON protocol: after the `{"sieb": 1}` header every line is one
# JSON value, so vault text cannot reach sieb's own syntax the way a NUL or
# a newline in an entry name could with rofi's in-band options.
def emit [value: record] {
    print ($value | to json --raw)
}

# A whole menu in one write. sieb holds a menu back for a moment until the
# row it is to select has arrived, so that it opens on that row instead of
# jumping to it. Rows printed one at a time, with an rbw call between
# them, take longer than it waits.
def emit-all [values: list] {
    print ($values | each {|value| $value | to json --raw } | str join "\n")
}

# Vault text for the prompt and message, which sieb draws as plain text:
# control characters out.
def plain []: any -> string {
    default "" | str replace --all --regex '\p{Cc}' " "
}

# Vault text in a row, where markup-rows is on: markup escaped too.
def shown []: any -> string {
    plain | str replace --all "&" "&amp;" | str replace --all "<" "&lt;" | str replace --all ">" "&gt;"
}

# A record this script put in `info` or `data` earlier, or an empty one
# for anything that does not parse as one.
def decode []: any -> record {
    let value = try { default "" | from json } catch { null }
    if ($value | describe) starts-with "record" { $value } else { {} }
}

def encode []: record -> string {
    to json --raw
}

# An entry as `info` or `data` carries it, or null unless its id is a real
# one.
def valid-entry []: any -> any {
    let entry = $in
    if ($entry | describe) starts-with "record" and ($entry.id? | default "") =~ $UUID {
        {id: $entry.id, name: ($entry.name? | default ""), type: ($entry.type? | default "")}
    }
}

# A field name: one line, as `rbw get --list-fields` prints it.
def valid-field []: any -> any {
    let field = $in
    if ($field | describe) == "string" and ($field | is-not-empty) and not ($field =~ '\n') {
        $field
    }
}

def valid-queue []: any -> list {
    default []
    | where {|it| ($it | describe) starts-with "record" }
    | where {|it| ($it.id? | default "") =~ $UUID and ($it.field? | valid-field) != null }
    | each {|it| {id: $it.id, field: $it.field, name: ($it.name? | default "")} }
}

def queue-text [queue: list]: nothing -> string {
    $queue | each {|it| $"($it.field | plain)@($it.name | plain)" } | str join ", "
}

# Keys on the entry list, each acting on one field of the selected entry.
# sieb sends the Nth as ROFI_RETV 10+N.
const ENTRY_KEYS = [
    [key action field];
    ["Alt+u" copy username]
    ["Alt+p" copy password]
    ["Alt+t" copy totp]
    ["Alt+Shift+u" type username]
    ["Alt+Shift+p" type password]
    ["Alt+s" sync ""]
]
# Keys on the field list, acting on the selected field.
const FIELD_KEYS = [
    [key action];
    ["Alt+c" copy]
]

# What the key behind `retv` does, out of `keys`, or null for Enter,
# Ctrl+Enter and anything unbound.
def custom-key [keys: list, retv: int]: nothing -> any {
    if $retv > 10 { $keys | get --optional ($retv - 11) }
}

# Where the entry last used is kept, or null without a runtime directory:
# that one is the user's alone and gone at logout, and nothing else is.
def state-file []: nothing -> any {
    let dir = $env.XDG_RUNTIME_DIR? | default ""
    if ($dir | is-empty) { null } else { $dir | path join "sieb-rbw.json" }
}

# With a field, the next start opens the entry's fields on that one.
def remember [entry: record, field?: string] {
    let file = state-file
    if $file == null { return }
    try { {entry: $entry, field: $field} | encode | save --force $file }
}

def forget [] {
    let file = state-file
    if $file != null { rm --force $file }
}

# What `remember` kept, each part null unless it still passes as one.
def recall []: nothing -> record {
    let file = state-file
    let kept = if $file != null and ($file | path exists) {
        (try { open --raw $file } catch { "" }) | decode
    } else {
        {}
    }
    {entry: ($kept.entry? | valid-entry), field: ($kept.field? | valid-field)}
}

def sync []: nothing -> string {
    let synced = ^rbw sync | complete
    if $synced.exit_code == 0 {
        "synced"
    } else {
        $"sync failed: ($synced.stderr | str trim | plain)"
    }
}

def menu-header [options: record, keys: list = []] {
    print '{"sieb": 1}'
    let custom = $keys | get --optional key | default [] | str join ","
    emit ({prompt: "rbw", no-custom: true, markup-rows: true, custom-keys: $custom} | merge $options)
}

# `note` leads the message, and the entry with id `select` starts selected.
def entries-menu [queue: list, note: string = "", select?: string] {
    menu-header {data: ({queue: $queue} | encode)} $ENTRY_KEYS
    if (^rbw unlocked | complete).exit_code != 0 {
        emit {message: "The vault is locked: run rbw unlock first"}
        emit {text: "locked", selectable: false}
        return
    }
    let list = ^rbw list --raw | complete
    if $list.exit_code != 0 {
        emit {message: $"rbw list failed: ($list.stderr | str trim | plain)"}
        # rbw lists all or nothing, so one entry that no longer decrypts
        # hides the rest. `rbw edit` leaves entries like that behind.
        let hint = if ($list.stderr =~ "invalid mac") {
            "an entry no longer decrypts: repair or delete it in another client (doy/rbw#364)"
        } else {
            "failed"
        }
        emit {text: $hint, selectable: false}
        return
    }
    # One line of the message box: 86 characters at the launcher theme's
    # width and font size. Anything longer wraps or is cut.
    let status = if ($queue | is-empty) {
        "Enter: login  Ctrl+Enter: fields  Alt+u/p/t: copy  Alt+Shift+u/p: type  Alt+s: sync"
    } else {
        $"queued: (queue-text $queue)"
    }
    let message = {message: ([$note $status] | where {|it| $it | is-not-empty } | str join "    ")}
    # Rows above the entries, which `new-selection` counts too.
    let above = if ($queue | is-empty) {
        []
    } else {
        [
            {text: "\u{f11c} type the queue", info: ({do: "type-queue"} | encode)}
            {text: "\u{f1f8} clear the queue", info: ({do: "clear"} | encode)}
        ]
    }
    let entries = $list.stdout | from json | where {|it| $it.id =~ $UUID }
        | sort-by {|e| $e.folder | default ""} name
    let at = $entries | enumerate | where {|it| $it.item.id == $select } | get --optional 0.index
    let selection = if $at == null { [] } else { [{new-selection: ($at + ($above | length))}] }
    let rows = $entries | each {|it|
        let folder = if ($it.folder | is-empty) { "" } else { $"($it.folder | shown)/" }
        let detail = if $it.type == "Login" { $it.user } else { $it.type }
        let entry = {do: "entry", id: $it.id, name: $it.name, type: $it.type}
        {
            text: $"($folder)($it.name | shown)  <span alpha='55%'>($detail | shown)</span>"
            info: ($entry | encode)
        }
    }
    emit-all [$message ...$selection ...$above ...$rows]
}

# A field's value for display, only ever one in SHOWN.
def read-shown [id: string, field: string]: nothing -> string {
    if not ($field in $SHOWN) { return "" }
    let got = ^rbw get --field $field $id | complete
    if $got.exit_code == 0 { $got.stdout | str trim --right } else { "" }
}

# The field named `select` starts selected.
def fields-menu [entry: record, queue: list, select?: string] {
    let hint = "Enter: queue  Ctrl+Enter: type  Alt+c: copy"
    let message = if ($queue | is-empty) { $hint } else { $"($hint)    queued: (queue-text $queue)" }
    menu-header {
        prompt: ($entry.name | plain)
        message: $message
        data: ({queue: $queue, entry: $entry} | encode)
    } $FIELD_KEYS
    let back = {text: "\u{f060} back", info: ({do: "back"} | encode)}
    let listed = ^rbw get --list-fields $entry.id | complete
    if $listed.exit_code != 0 {
        emit $back
        emit {text: $"rbw failed: ($listed.stderr | str trim | shown)", selectable: false}
        return
    }
    let fields = $listed.stdout | lines | where {|f| $f | is-not-empty }
    # In row order, after the back row: the notes are listed last.
    let order = $fields | where {|f| $f != "notes" } | append ($fields | where {|f| $f == "notes" })
    let at = $order | enumerate | where {|it| $it.item == $select } | get --optional 0.index
    let selection = if $at == null { [] } else { [{new-selection: ($at + 1)}] }
    let named = $fields | where {|f| $f != "notes" } | each {|field|
        let glyph = $GLYPHS | get --optional $field | default $GLYPH_OTHER
        let value = read-shown $entry.id $field | lines | str join ", "
        let value = if ($value | is-empty) { "" } else { $"  <span alpha='55%'>($value | shown)</span>" }
        {text: $"($glyph) ($field | shown)($value)", info: ({do: "field", field: $field} | encode)}
    }
    let notes = if "notes" in $fields {
        [{text: $"($GLYPHS.notes) copy the notes", info: ({do: "copy", field: "notes"} | encode)}]
        | append (read-shown $entry.id "notes" | lines | each {|line|
            {text: $"<span alpha='70%'>($line | shown)</span>", selectable: false}
        })
    } else {
        []
    }
    emit-all [...$selection $back ...$named ...$notes]
}

# The sh side, run detached so sieb closes and focus goes back. $1 to $3
# are the delays, the rest is the action's. `$(...)` drops rbw's trailing
# newline, which wtype would type as Enter, and printf is a shell builtin,
# so the secret is never an argument of a process. Every way out short of
# success says why in a notification, since nothing else is watching.
const SH_PRELUDE = r#'
delay=$1 keys=$2 clear=$3
shift 3
nl="
"
err=$(mktemp) || exit 1
trap 'rm -f "$err"' EXIT
fail() {
    notify-send -a rbw -u critical "$1" "$(printf %s "$2" | tr -d "<>&")"
    exit 1
}
# Sets $v to what rbw prints for its arguments, or fails with rbw stderr.
get() { v=$(rbw "$@" 2>"$err") || fail "rbw failed" "$(cat "$err")"; }
# A value to type: present, and on one line, since wtype types a newline
# as Enter and a terminal would run whatever came before it.
typeable() {
    [ -n "$1" ] || fail "Nothing to type" "The entry has no $2"
    case $1 in *"$nl"*) fail "Not typing the $2" "It spans several lines" ;; esac
}
type_out() { printf %s "$1" | wtype -d "$keys" - || fail "wtype failed" ""; }
copy() {
    [ -n "$1" ] || fail "Nothing to copy" "The entry has no $2"
    printf %s "$1" | wl-copy --sensitive || fail "wl-copy failed" ""
    notify-send -a rbw "Copied the $2" "Clears in ${clear}s"
    sleep "$clear"
    [ "$(wl-paste -n 2>/dev/null)" = "$1" ] && wl-copy --clear
}
'#

const SH_ACTIONS = {
    # $1 the entry id.
    autotype: '
get get --field username "$1"; u=$v
get get "$1"; p=$v
typeable "$u" username; typeable "$p" password
sleep "$delay"
type_out "$u"; wtype -k Tab; type_out "$p"
# As rofi-rbw does: a TOTP is the next thing a login asks for.
c=$(rbw code "$1" 2>/dev/null) && [ -n "$c" ] && copy "$c" "TOTP code"
'
    # $1 the entry id, $2 the field.
    type: 'get get --field "$2" "$1"; typeable "$v" "$2"; sleep "$delay"; type_out "$v"'
    copy: 'get get --field "$2" "$1"; copy "$v" "$2"'
    # Pairs of entry id and field. Every value is read and checked before
    # the first key goes out, so a missing one types nothing at all. The
    # eval only ever names the variables, the values stay in them.
    queue: '
n=0
while [ $# -ge 2 ]; do
    get get --field "$2" "$1"; typeable "$v" "$2"
    n=$((n + 1)); eval "q$n=\$v"
    shift 2
done
sleep "$delay"
i=1
while [ "$i" -le "$n" ]; do
    [ "$i" -gt 1 ] && wtype -k Tab
    eval "type_out \"\$q$i\""
    i=$((i + 1))
done
'
}

def act [action: string, ...args: string] {
    let program = $SH_PRELUDE + ($SH_ACTIONS | get $action)
    let delays = [$TYPE_DELAY $KEY_DELAY $CLEAR_AFTER] | each { into string }
    # Detached and with its output closed, so sieb sees the script finish.
    ^setsid -f sh -c $program rbw ...$delays ...$args o+e> /dev/null
}

def main [choice?: string] {
    if $choice == null {
        if ($env.RBW_PICKER_FRESH? | is-not-empty) { forget }
        let last = recall
        return (if $last.entry != null and $last.field != null {
            fields-menu $last.entry [] $last.field
        } else {
            entries-menu [] "" $last.entry.id?
        })
    }
    let data = $env.ROFI_DATA? | decode
    let queue = $data.queue? | valid-queue
    let entry = $data.entry? | valid-entry
    let pick = $env.ROFI_INFO? | decode
    let field = $pick.field? | valid-field
    let retv = try { $env.ROFI_RETV? | default "1" | into int } catch { 1 }
    let more = $retv == 10
    # Whatever row it was pressed on. Only the entries bind it, and their
    # `data` names no entry.
    let pressed = if $entry == null { custom-key $ENTRY_KEYS $retv }
    if $pressed != null and $pressed.action == "sync" {
        return (entries-menu $queue (sync) $pick.id?)
    }
    match ($pick.do? | default "") {
        "entry" => {
            let picked = $pick | valid-entry
            if $picked == null { return }
            let key = custom-key $ENTRY_KEYS $retv
            if $key != null {
                remember $picked
                act $key.action $picked.id $key.field
            } else if $picked.type == "Login" and not $more {
                remember $picked
                act autotype $picked.id
            } else {
                fields-menu $picked $queue
            }
        }
        "type-queue" if ($queue | is-not-empty) => {
            act queue ...($queue | each {|it| [$it.id $it.field] } | flatten)
        }
        "clear" => { entries-menu [] }
        "back" => {
            # Off the field list for the next start as well.
            if $entry != null { remember $entry }
            entries-menu $queue "" $entry.id?
        }
        "field" if $entry != null and $field != null => {
            let key = custom-key $FIELD_KEYS $retv
            if $key != null {
                remember $entry $field
                act $key.action $entry.id $field
            } else if $more {
                remember $entry $field
                act type $entry.id $field
            } else {
                entries-menu ($queue | append {id: $entry.id, field: $field, name: $entry.name})
            }
        }
        "copy" if $entry != null and $field != null => {
            remember $entry $field
            act copy $entry.id $field
        }
        _ => {}
    }
}
