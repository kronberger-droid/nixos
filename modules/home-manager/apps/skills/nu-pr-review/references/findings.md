# Findings: file format, severity, voice

Shared by `nu-pr-review` and `nu-pr-recheck`. `scripts/gh_review.py` turns the file into the posted review: the "Review overview" layout lives in the script. There are no severity badges. In a thread, severity is carried by the wording. The overview spells it out in plain text: a `**Findings:** 2 high · 3 medium · 0 low` line, and each linked finding led by `High:`, `Medium:` or `Low:`.

## The file

`findings.json` in the PR's tools dir, or `recheck_findings.json` for a recheck.

```json
{
  "repo": "nushell/nushell",
  "pr": 19362,
  "sha": "<full 40-char head sha the findings were checked on>",
  "summary": "One or two sentences: what works, then what's left.",
  "footer": "I used Claude to check this on 98b025d30. Built the branch, ran `cargo test -p nu-command --test tests -- split_column` (5 passed) and clippy with CI's flags (2 errors), and ran each case on the branch binary and on 0.116.2.",
  "findings": [
    {"sev": "medium", "path": "crates/nu-command/src/strings/split/column.rs", "line": 319,
     "title": "Helper placed after the test module fails clippy",
     "text": "markdown body of the thread, without the title"},
    {"sev": "low", "reply_to": 4392683538,
     "title": "Release note for unused names is still missing",
     "text": "Rechecked on 98b025d30. ..."}
  ],
  "resolve": [
    {"thread": 4392683458, "why": "`check_duplicate_columns` sits above `mod test` on 98b025d30, and clippy with CI's flags is clean."}
  ],
  "keep": [
    {"thread": 4392683470, "why": "My finding from 13:16 still stands: no commits or replies since."}
  ]
}
```

Each finding is one of three kinds:

- **Line thread** (the default). `line` is the RIGHT-side (new file) line; add `start_line` for a range. Both must sit inside a diff hunk.
- **File-level thread** (`"subject": "file"`), for a changed file whose relevant line is outside the hunks. Give `line` (and `start_line`) anyway: the script appends the blob permalink. A finding about a file the PR doesn't touch goes on the changed line it is really about (the `use` line that brings the API in, the call site).
- **Reply finding** (`reply_to`: the first comment id of an existing thread), for a recheck point that isn't addressed. It's posted as a reply inside the same review, and `post` unresolves the thread.

Other keys:

- `title`: a short claim, unique within the file (the script links each posted comment by its title).
- `resolve` (recheck): addressed threads, by first-comment id or thread node id, each with a one-sentence `why` naming the evidence.
- `keep` (recheck): threads left exactly as they are (the user's finding still stands, another reviewer's open question), same shape. Nothing is sent; the preview shows each with its reason.
- `heading`: defaults to `Changes recommended`.
- `footer`: starts "I used Claude to check this on <short sha>." and says what was built and run, with test counts, and what wasn't run.
- `summary` and `footer` are needed only with findings. A recheck with only `resolve` posts no review; one with only `keep` sends nothing.

## Severity

By what happens if the author doesn't fix it. `sev` orders the overview, is counted and named there, and picks the framing of the thread. The thread itself carries no label:

- **high**: changes behavior, gives wrong output with no error, regresses something main does right, or needs a design decision before merge. Frame it as a blocker: say what stops the merge and what would unblock it.
- **medium**: should be fixed before merge: rejects valid input, fails CI (clippy, fmt, tests), loses test coverage, a new command or flag with no `examples()` entry, a fix that misses part of its own stated scope. Frame it as "Two small things before we land it:" style changes.
- **low**: a nit: naming, duplication, a stale or wrong comment, a missing doc comment, a test that could be tighter, a missing release note. A bare sentence, or a question for a suggestion ("Maybe add a positive test for X?").

A pre-existing bug the PR doesn't touch isn't a finding; one inside the PR's stated scope (it claims to fix that class of bug) is. A reply finding keeps its thread's severity unless what's left is smaller.

## Voice

Every thread goes out under the user's name, often to a new contributor. Load the `github-voice` skill (review kind) before writing any thread, summary or footer: it is the voice, and it wins over anything below where they differ. That means one clause per line, `since` over `because`, pushback opening `Hmm` and agreement `Yeah`, no emoji, no em-dashes, no "LGTM" or "nit:", and a closing landing verdict in the summary. LLM use is disclosed in the footer, in plain first person. On top of that, for review threads on a Nushell PR:

- **Lead with behavior.** Name the command, then what the branch gives and what main gives, with real probe output trimmed to the lines that matter:

  ````markdown
  On 98b025d30:

  ```nu
  'a' | split column '-' x x | to nuon
  # main:   [[x]; [a]]
  # branch: Error: nu::shell::column_defined_twice
  ```
  ````

- **Give the fix**, short: the existing helper to reuse, where the code should move, or a ```` ```suggestion ```` block for a one-line change. Quote the AGENTS.md rule when one applies.
- **Keep scope fair.** For something adjacent: "Fine as a follow-up if you'd rather keep this PR to `random-list`."
- **Answer the author's own question** when the finding is one, rather than framing it as a mistake.
- **Say what was read rather than run**: "From reading the code; I didn't run this on Windows."
- Plain words and short sentences, no praise or hedging filler.
