#!@nu@/bin/nu -n

# Fuzzy picker over the khard address book, in the style of eww/nu/*.nu:
# a real .nu file, store paths substituted by replaceVars, no bare names.
#
# The pipeline this sits on top of is in contacts.nix: Radicale (homeserver,
# over the tailnet) <-> vdirsyncer <-> ~/.local/share/contacts <-> khard.
# This script adds nothing to it, it just makes khard usable across 400
# contacts where `khard edit <name>` needs you to remember the name.
#
# Selection is by UID, never by name: `khard edit "Adam Lagin"` prompts for a
# disambiguation choice whenever two contacts share a name, which breaks a
# non-interactive pipe. UIDs work as plain search terms and are unique.

# One row per contact: "uid \t name \t emails \t phones".
#
# khard renders emails and phones as python dict reprs, e.g.
#   {'home': ['zivildienst@wrk.at']}
# Parsing that properly is not worth it: the picker only needs the row to be
# searchable and readable, so the quoted values are scraped out and joined.
def rows []: nothing -> list<string> {
  let raw = (^@khard@/bin/khard list --parsable -F uid,formatted_name,emails,phone_numbers | complete)
  if $raw.exit_code != 0 { return [] }

  $raw.stdout | lines | each {|line|
    let f = ($line | split row "\t")
    let uid = ($f | get 0? | default "")
    let name = ($f | get 1? | default "")
    # Pull every '...' out of the dict repr, drop the type keys (home, cell,
    # work), keep the values: anything with an @ or a leading +.
    let vals = {|s|
      $s
      | default ""
      | parse --regex "'(?<v>[^']+)'"
      | get v
      | where {|v| ($v | str contains "@") or ($v | str starts-with "+")}
      | str join ", "
    }
    let mails = (do $vals ($f | get 2?))
    let phones = (do $vals ($f | get 3?))
    # A marker on contacts with no address, so the ones still needing an email
    # are findable by typing the marker into the picker.
    let mark = if ($mails | is-empty) { "no-email" } else { "" }
    $"($uid)\t($name)\t($mails)\t($phones)\t($mark)"
  }
}

# Sync once, before anything is read.
#
# This is the whole conflict story. vdirsyncer cannot resolve a card that both
# sides changed since the last sync, and `conflict_resolution` is unset here,
# so such a card errors and stops syncing until it is fixed by hand. Editing a
# *stale* copy is what creates that case: the phone (DAVx5 -> the same
# Radicale) writes, this copy goes stale, an edit on top of it diverges.
#
# Syncing here makes the local copy current, so whatever is written next is a
# fast-forward on the remote rather than a divergence. Pushing it back is then
# only latency, and vdirsyncer.timer already does that every 5 minutes — which
# is why there is no sync on the way out.
def sync-now [] {
  print -n "syncing… "
  let r = (^@vdirsyncer@/bin/vdirsyncer sync | complete)
  if $r.exit_code == 0 {
    print "ok"
  } else {
    # Offline, or the tailnet is down. Stale contacts still beat no contacts,
    # so this warns and carries on rather than refusing to start.
    print "failed — editing a possibly stale copy"
    print ($r.stderr | str trim | lines | last 3 | str join "\n")
  }
}

# Loops rather than editing once and exiting: filling in a backlog of missing
# addresses is many edits in one sitting, and re-listing after each one means
# a contact that just got an address loses its `no-email` marker immediately.
def main [...search: string] {
  sync-now

  mut query = ($search | str join " ")

  loop {
    let rows = (rows)
    if ($rows | is-empty) {
      print "no contacts — is vdirsyncer.timer running?"
      return
    }

    # --with-nth 2.. hides the uid from the display and from matching, but
    # keeps it as {1} for the preview and in the selected line.
    #
    # Flags as one list rather than spread across lines: nushell ends an
    # external command at the newline, so a continuation line inside a block
    # parses as a new expression. Same reason eww/nu/tui.nu builds its
    # dropkitten args this way.
    let flags = [
      "--delimiter" "\t"
      "--with-nth" "2.."
      "--prompt" "contact> "
      "--query" $query
      "--preview" "@khard@/bin/khard show {1}"
      "--preview-window" "right:55%"
      "--no-multi"
    ]
    # No --select-1. It is documented as "skip the TUI if -q matches only one
    # item", but skim evaluates that before stdin has been fully ingested: with
    # 400 rows still streaming in it sees one match, skips the picker and
    # returns the first contact. Pre-seeding --query filters the list anyway,
    # which is the behaviour that flag was there for.

    # NOT `| complete`. skim draws its whole interface on *stderr* (stdout is
    # reserved for the selection, which is what makes `let x = (… | sk)` work),
    # and `complete` captures stderr into a record — which renders the picker
    # into a variable and leaves the terminal blank while skim waits for keys.
    # Bare like this, stdout is captured and stderr goes to the terminal.
    #
    # try/catch rather than an exit-code check for the same reason: reading the
    # code means capturing, and skim exits non-zero on Escape and ctrl-c.
    let picked = (try {
      $rows | str join "\n" | ^@skim@/bin/sk ...$flags | str trim
    } catch { "" })

    # Escape / ctrl-c out of the picker gives no selection, which ends it.
    let uid = ($picked | split row "\t" | get 0? | default "")
    if ($uid | is-empty) { break }

    # Not piped and not captured: khard hands the terminal to $EDITOR, which
    # needs the tty. `| complete` here would leave helix drawing into a pipe.
    ^@khard@/bin/khard edit $uid

    # Only the first pass honours the argv query; after that the picker opens
    # clean so the next contact can be searched for.
    $query = ""
  }
}
