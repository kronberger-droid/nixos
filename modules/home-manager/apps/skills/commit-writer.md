---
name: commit-writer
description: Draft a git commit message from the staged diff, in Martin's voice.
when_to_use: >-
  Before every `git commit`, including when the commit is one step of a larger
  task and nobody asked for a message specifically. Also when amending or
  rewording an existing commit.
argument-hint: [scope-or-guidance]
user-invocable: true
allowed-tools: Read Grep Bash
---

Write for the **archaeologist**: someone who hits this commit from `git blame`
in two years with the diff already open in the next pane. They can read the
code. They cannot read the reasoning that never made it into the code.

## Body length tracks rationale, not diff size

**Subject-only is the default.** A 400-line vendored bump gets one line. A
three-line change hiding a trade-off gets four paragraphs.

Write a body only when at least one holds:

- a non-obvious trade-off, a rejected alternative, or a constraint that forced
  the shape of the change
- context living outside the repo: an upstream bug, a nixpkgs gap, a version
  caveat, why now
- a behaviour change someone would notice without reading the diff

Then run every surviving line through one test: **could the reader learn this
from the diff or from a comment already in the code?** If yes, delete the line
whole rather than rephrasing it. What is left is the body.

The guardrail this defends: a commit message is not the chat summary of the
work. No recap of what was done, no file-by-file tour.

## Subject

`type(scope): summary`

- lowercase after the colon, imperative, no trailing period, <= 72 chars
- `!` before the colon for a breaking change: `feat(vi)!: ...`
- types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `lock`,
  `update`
- take the scope vocabulary from the repo's own log, do not invent one

Spend the subject on *why* when it fits:
`fix(nchat): stop pre-creating the confdir it uses as a setup marker`
beats `fix(nchat): remove mkdir`.

## Voice

- hard-wrap the body at 72, since `git log` indents by 4 and does not reflow
- `since` and `thus`, not `because` and `therefore`
- backtick every identifier, file and path; reference issues bare (`#1100`)
- prose wraps, code does not: indent code blocks by 4 and leave them long
- no em-dashes, no emoji
- disclose LLM involvement with the `Co-Authored-By:` trailer

## Steps

1. Read `git diff --staged`. If nothing is staged, read `git diff` and
   `git status`, then ask which files belong in this commit rather than
   staging everything.
2. Scan `git log -n 30 --pretty=%s` for the scope vocabulary in use.
3. Draft the subject. If no single subject covers the staged files, the commit
   spans two changes: propose the split before writing further.
4. Apply the body gate above.
5. Commit with one `-m` per paragraph, so no literal `\n` reaches the message.
