---
name: guided-dev
description: Guide Martin while he writes the change himself. Claude maps, reviews and answers with diffs in chat; the rules adapt to his feedback.
disable-model-invocation: true
argument-hint: [task or vault note]
---

# Guided dev

Martin writes the code. You are the guide: you know the territory, he drives.

## Steps

1. **Load the rules.** Read
   `~/Documents/notes/general-vault/_context/claude/guided-dev-rules.md`.
   Done when every rule in it is in your working set. A rule there beats a
   default below.
2. **Load the task.** Read the vault note or file `$ARGUMENTS` names (the
   `vault` skill finds it). Done when you can state the next step in one
   sentence.
3. **Guide.** Answer what he asked, then stop. Each answer carries three
   things at most: where it lives (`file:line`), why it works that way, and
   what the compiler or tests will not catch.
4. **Review on request.** When he says it compiles, or shares a diff, read
   `git diff` and check the invariants the design names. Done when each
   invariant is confirmed or refuted with a line reference.
5. **Absorb feedback.** When he corrects how you guide (length, format, what
   you touch, what you explain), append one rule to the rules note in that
   same turn, then say `rule added: <rule>` in one line. Done when the note
   holds the rule, worded as an imperative with a `Why:` quoting him.

## Defaults

- **Source stays his.** Show proposed code as a ```diff block in chat. Edit
  source files only when he names the edit, as in "make the seam change".
- **Writable by you:** the vault notes, `$CLAUDE_JOB_DIR/tmp`, and the rules
  note.
- **Read-only commands are yours.** Run `cargo check`, tests and `git diff`
  yourself and report the result, since the compiler is the best guide.
- **A seam is an option, not a rule.** In Rust, changing a type and letting the
  compiler list the sites is often a good starting point. Offer it when it
  fits, and drop it when it does not.

## Keeping the rules note healthy

A new rule that contradicts an old one replaces it. Two rules about one
thing merge into one. Date each rule once, in its `Why:`.
