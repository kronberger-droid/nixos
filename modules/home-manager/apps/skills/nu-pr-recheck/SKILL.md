---
name: nu-pr-recheck
description: "Recheck a nushell/nushell or nu_scripts PR the user already reviewed: verify each review thread on the new head, resolve the addressed ones, and reply with a finding on the rest. Use when asked to recheck a PR, to check whether review comments were addressed, or to resolve review threads. Resolving and replying always need a fresh yes."
---

# Nushell PR recheck

A recheck answers one question per review thread: is it addressed on the current head? Addressed threads get resolved. Each one that isn't gets a reply finding and is unresolved so it shows as open. It all goes out under the user's account, so each verdict rests on a run against the new head, not on the author saying "fixed".

`$N` is the PR number, `$R` the repo (`nushell/nushell` unless the URL says otherwise), `$S=~/.claude/skills/nu-pr-review/scripts`, `$T` the PR's tools dir. The findings format, severity and voice are in `~/.claude/skills/nu-pr-review/references/findings.md`.

## 1. Load what was posted

```sh
ls -d ~/Projects/nushell-review/pr${N}_*; cat ~/Projects/nushell-review/pr${N}_*/README.md
python3 $S/gh_review.py threads --repo $R --pr $N --full
gh pr checks $N --repo $R
```

The README gives the review ids, the dropped findings and what to rerun, and `$T` holds `probe.sh` and the earlier findings files. `threads` marks the commits after the user's latest review as NEW, or says the branch was force-pushed, which makes the whole diff new.

Done when you have every review thread (first-comment id, who started it, title, severity, resolved or open, the author's reply) and the commits since the last review. Every thread is in scope, Copilot's and other reviewers' included: the user resolves those too once they're fixed.

## 2. Start code-review and the build

When the head is still the one the last review or recheck checked (the README names it, and `threads` shows no NEW commits), those runs still hold: skip this step, and judge only what changed in the threads since (author replies, threads the author resolved). Otherwise, in one message:

- invoke the `code-review` skill (`skill: code-review`, `args: high <PR URL>`, neither `--comment` nor `--fix`) for a fresh look at them;
- run `$S/pr_worktree.sh $N $R` with `run_in_background`. It moves the worktree to the head and builds it, or creates it; exit 3 means local changes: ask the user.

## 3. Give every thread a verdict

Rerun `probe.sh` on the new binary. Add a `recheck.sh` beside it for what the fixes need that it doesn't cover: the fix's side effects and the code paths the author touched. Run `cargo test` or clippy only for what `gh pr checks` doesn't already show green on this head.

A thread is **addressed** when one of these holds:

- the probe, a test or clippy on the new head shows the fix;
- the author defers it to a follow-up the thread allowed ("fine as a follow-up") or the user agreed to;
- the author kept the behavior with a reason the user would accept.

Otherwise it is **not addressed**: the probe still shows the problem, the fix leaves a case, or the reply says "fixed" and the code says otherwise. A thread the author resolved without fixing it counts as not addressed.

When the user's own finding in a thread is newer than the author's last commit and reply, and nothing changed since, that finding stands: the thread is a `keep`.

When code-review reports back, probe its candidates and dedupe them against every thread, resolved ones included, and against the dropped findings in the README. A problem the new commits introduced that no thread covers becomes a new line finding.

Done when every thread has a verdict backed by a run or a diff read.

## 4. Write and preview the recheck file

Load the `github-voice` skill (review kind), then write `$T/recheck_findings.json` from `findings.md` alone, which is the complete format:

- a `resolve` entry per addressed thread, its `why` naming the evidence ("`recheck.sh` on 0b3de87c9: `exit 3` under `NU_BACKTRACE=1` now exits 3");
- a reply finding per thread that isn't addressed: `reply_to` its first comment id, a title naming what's still wrong, and text starting "Rechecked on <short sha>." with the new-head output and the fix;
- a `keep` entry, with its reason, per thread left as it is;
- a line finding per new problem;
- `summary`: how many threads are fixed and resolved, then what's left. `footer`: "I used Claude to check this on <short sha>." and what was run.

```sh
python3 $S/gh_review.py post $T/recheck_findings.json --dry-run $T/dry_run
```

It runs the checks, sends nothing, and writes `dry_run/preview.html`. Done when it prints `ok:` and the preview reads right: each reply under the thread it answers, each resolve and keep with its reason.

## 5. Act

Never act on the strength of the original request, even one that said "resolve them" or "comment on what isn't addressed". Resolving, unresolving and replying are outward-facing and visible to the author and the other reviewers. Give the user the preview path and the verdict list, then ask, naming the exact action: "resolve N threads, reply on M, and post one review with K new threads on `$R#$N`, pinned to `<short sha>`". Act only after a yes to that question. A yes covers that one run, not a later one on a new head.

```sh
python3 $S/gh_review.py post $T/recheck_findings.json
```

It rechecks the head, posts one COMMENT review with the reply findings and new threads (an overview links each), unresolves every thread that got a reply finding, and resolves the `resolve` list. With no findings it only resolves.

## 6. Record and report

Add a "Recheck on <sha> (<date>)" section to `$T/README.md` naming `recheck.sh` and `recheck_findings.json`, with the threads resolved, each open thread with its reply id and the review id. That file is the record, nothing goes to memory.

Tell the user: resolved N of M, each thread left open with a one-line reason and its link, the review link, CI state on the head, and anything checked only by reading the code.

The skill's output is resolves, reply findings, unresolves, once confirmed, and the local notes. Commits, pushes, issues and PRs are outside it.
