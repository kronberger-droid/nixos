---
name: nu-pr-review
description: "Review a nushell/nushell or nu_scripts PR and post each finding as its own review thread, verified on a built branch binary. Use when asked to review a PR, to post /code-review findings on a PR, or for \"a review comment for each finding\". A PR the user already reviewed goes to nu-pr-recheck. Posting always needs a fresh yes."
---

# Nushell PR review

The review goes out under the user's GitHub account, so every finding has to be one the user would stand behind: run on a real binary, not already raised on the PR, and written in the voice of the `github-voice` skill.

`$N` is the PR number, `$R` the repo (`nushell/nushell` unless the URL says otherwise), `$S` this skill's `scripts/` dir, `$T` the PR's tools dir `~/Projects/nushell-review/pr${N}_<slug>/` (outside every repo, so nothing gets committed).

## 1. Read the PR

```sh
gh pr view $N --repo $R --json title,body,author,headRefOid,files,statusCheckRollup; gh pr diff $N --repo $R
python3 $S/gh_review.py threads --repo $R --pr $N --full
```

Done when you can say: the head sha, what the PR claims to fix (and the issue it closes), which CI jobs ran (a first-time contributor's PR often ran only triage, so clippy and tests are unchecked), and every point already raised, by whom, and whether the user called it settled ("fine leaving", "it's probably ok"). Copilot's review counts as raised.

- A review of the user's already on the PR makes this a recheck: switch to `nu-pr-recheck`.
- "Depends on <sha>", or another PR's commits in the diff, means it's stacked: `gh pr list --repo $R --author <author> --state all` and match commit titles. Findings in the other PR's commits belong to that PR.

## 2. Start code-review and the build

Both run in the background while you do step 3. In one message:

- Invoke the `code-review` skill: `skill: code-review`, `args: <PR URL>`, with neither `--comment` nor `--fix`. It runs on every review, even when step 1 already points at the answer, unless it ran on this PR earlier in this conversation.
- Run `$S/pr_worktree.sh $N $R` with `run_in_background`: it checks the head out in `<clone>/.claude/worktrees/pr_$N` (`~/Projects/rust/nushell` or `~/Projects/rust/nu_scripts`), builds it on a cloned target (nu_scripts needs no build), and prints the branch binary and the "before" one, the installed `nu` (upstream main), with its commit next to main's. Call both by full path: a bare `nu` is the installed main build, not the branch. Exit 3 means the worktree has local changes: ask the user.

The worktree is for reading and probing: no commits, nothing pushed.

## 3. Find and verify

Read the diff against what step 1 says the PR is for. `code-review` reads only code, so it misses scope gaps (fixes `def` but not `alias`), missing tests for the stated fix, missing `examples()` entries, and release notes that skip a behavior change. Add its findings when it reports back.

Write `$T/probe.sh`, a one-line usage comment on top, that runs each candidate on both binaries:

```sh
#!/usr/bin/env bash
# Probe <what> on main (installed nu) vs PR #N. usage: probe.sh [branch_nu]
B=${1:-$HOME/Projects/rust/nushell/.claude/worktrees/pr_N/target/debug/nu}; M=$(command -v nu)
for c in "'a-b' | split column '-' col col | to nuon" ; do
  echo "== $c"; echo "-- main:"; NO_COLOR=1 $M --no-config-file -c "$c" 2>&1
  echo "-- branch:"; NO_COLOR=1 $B --no-config-file -c "$c" 2>&1
done
```

Where CI hasn't run clippy or the tests on this head, run them in the worktree, scoped to the touched crates:

```sh
cargo clippy -p <crate> --profile ci --all-targets -- -D warnings -D clippy::unwrap_used -D clippy::unchecked_time_subtraction
cargo test -p <crate> --test tests -- <filter>
cargo fmt --all --check && typos <changed files>
```

Every candidate ends in one state:

- **verified**: the probe, clippy or a test shows it on the branch binary. Its output goes into the thread.
- **read-only**: it can't run here (Windows-only, needs a network service). It can still be posted, saying it comes from reading the code.
- **dropped**: the probe shows no bug, or it's already raised, settled by the user, pre-existing on main and outside the PR's scope, or documented behavior.

A trial patch that proves a suggested fix is worth its build for a high or medium whose fix isn't obvious; revert it with `git checkout -- .` and rebuild before probing again. A low gets its suggestion from reading.

Done when every candidate has a state, and the dropped ones are listed with reasons in `$T/README.md` so a recheck doesn't raise them.

## 4. Write and preview the findings

Load the `github-voice` skill (review kind), then write `$T/findings.json` from `references/findings.md`: it is the complete format, severity rubric and voice. Pin `sha` to the full head sha you verified on.

```sh
python3 $S/gh_review.py post $T/findings.json --dry-run $T/dry_run
```

It sends nothing, writes `dry_run/preview.html` (the review as GitHub will render it), and lists any problems: a moved head means re-verify on the new head; a line outside the diff hunks comes with the commentable ranges, so move the finding to a changed line it's about or make it `"subject": "file"`. Done when it prints `ok:` and the preview reads right.

## 5. Post, or hand over

Never post on the strength of the original request, even one that said "post" or "leave a comment for each finding". Posting is outward-facing and a review cannot be deleted once submitted. Give the user the `preview.html` path and the findings, numbered with severities, then ask, naming the exact action: "post one COMMENT review with N threads on `$R#$N`, pinned to `<short sha>`". Post only after a yes to that question. A yes covers that one post, not a later one on a new head.

```sh
python3 $S/gh_review.py post $T/findings.json
```

`post` rechecks the head, posts one COMMENT review pinned to `sha` with a thread per finding, links each thread from the "Review overview" body, and writes `findings.posted.json`. If it stops after the review exists, fix the cause and run `gh_review.py link $T/findings.json --review <id>`: a submitted review can't be deleted, so a second post would leave two copies up. Done when it prints `verified`.

## 6. Record and report

Append to `$T/README.md`: the review id, head sha, files, counts, one line per finding, what was dropped and why, the worktree state, and what a recheck should rerun. That file is the record, nothing goes to memory.

Tell the user: the review link, the head sha, counts by severity, what was built and run (and what's from reading the code only), and each dropped finding in one line.

The skill's output is the posted review, once confirmed, and the local notes. Commits, pushes, issues and PRs are outside it.
