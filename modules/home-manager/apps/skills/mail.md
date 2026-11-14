---
name: mail
description: Read, search, draft, send and delete mail with himalaya across Martin's two accounts.
when_to_use: >-
  Whenever a task involves reading, searching, replying to, drafting, sending
  or deleting email, for either the TU Wien or the GMX account.
allowed-tools: Bash Read
---

# Mail with himalaya

Mechanics only. `himalaya` is configured in `modules/home-manager/apps/mail.nix`;
the config is generated, so change it there.

## Accounts

Always pass `-a`; do not rely on the default (`gmx`).

| `-a` | Address | Use |
| --- | --- | --- |
| `tuwien` | kronberger@iap.tuwien.ac.at | Default for anything sent. University, work, open source. |
| `gmx` | martin.kronberger@gmx.at | Private mail, bookings, shops, banking. |

Send from `tuwien` unless the mail is private or the thread is already on GMX.
The login behind `tuwien` is `mkronber@intern.tuwien.ac.at`; the From address is
the iap alias.

## Commands

```sh
himalaya -a tuwien mailbox list
himalaya -a tuwien envelope list -m Inbox -s 20
himalaya -a tuwien envelope search -m Inbox from kiberatung or subject offer
himalaya -a tuwien message read <id>            # headers plus text parts
himalaya -a tuwien message read <id> --raw      # RFC 5322 bytes, for Message-ID
himalaya -a tuwien message add -m drafts < reply.eml   # save a draft
```

`-m` takes a folder name or role. `envelope list` and `search` take `-s` for page
size. Message ids are per folder, so pair every id with its folder.

## Searching

A mail is rarely where you first look. Search every folder of the relevant
account, and both accounts when the sender is unknown. TU Wien has many custom
folders (Official, Privat, IT, Lab Data Management, ...). Loop over
`mailbox list` output rather than guessing.

## Account quirks

- **tuwien SMTP** offers GSSAPI, NTLM and LOGIN, and rejects PLAIN. The config
  uses `smtp.sasl.login`. A `504 5.7.4 Unrecognized authentication type` means
  the config lost that.
- **tuwien folders:** trash is `Deleted Items`, sent is `Sent Items`. A plain
  `Sent` folder also exists and is not the real one.
- **gmx folders** are German and IMAP-UTF-7 on the wire: `Entwürfe`, `Gesendet`,
  `Gelöscht`, `Spamverdacht`.

## Replying

Write the message as a file under `$CLAUDE_JOB_DIR/tmp/` with `From`, `To`,
`Subject`, `In-Reply-To` and `References` (copy the Message-ID from
`message read --raw`), then `MIME-Version`, `Content-Type: text/plain;
charset=UTF-8`, `Content-Transfer-Encoding: 8bit`, a blank line, the body.
Prose follows `github-voice` and `humanizer`. Reply in the language of the
thread, informal "Du" unless the other side is formal.

## Gates

Reading, searching and saving a draft are free. Everything else needs a yes from
Martin for that specific action, never carried over from an earlier one:

- **Send:** show the full draft first. `himalaya -a tuwien message send --save
  "Sent Items" < file.eml`. This is also ask-gated in settings.
- **Delete or move:** name the mails (id, folder, sender, subject) and ask.
  `message delete` moves to trash first and removes for good when run on a mail
  already in the trash, so permanent deletion is two steps.

## Credentials

The password comes from a command in the config, so nothing here ever needs it.
Never run `himalaya` with `--debug`, `--trace` or `--log-level` above `warn`,
never `curl -v` against the servers, and never read `/run/secrets/*`. Verbose
output echoes the auth exchange, and that is how a login once ended up in a
transcript.
