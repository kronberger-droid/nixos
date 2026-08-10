---
name: github-voice
description: Draft GitHub prose as Martin — review comments, issue replies, and PR bodies.
when_to_use: >-
  When writing anything that will be posted to GitHub under Martin's name: a
  review comment or reply, an issue comment, or a pull request body. Covers
  drafts written to a scratch file, and PRs you open yourself as one step of a
  larger task. For commit messages use `commit-writer` instead.
argument-hint: [review|issue|pr]
user-invocable: true
allowed-tools: Read Grep Bash WebFetch
---

Derived from ~144 comments and 16 PR bodies on `nushell/reedline`.

Only the directives live here. The evidence base, with verbatim quotes per rule
and the fuller short-form/long-form breakdown, is at
`~/Documents/notes/general-vault/_context/claude/github-writing-style.md`.
Read it to calibrate phrasing closely, or when a rule below feels
underspecified.

## Both registers

- **One clause per line, soft-wrapped.** Break at sentence and idea boundaries
  only, never at a column limit. A clause runs as long as it needs and GitHub
  wraps it for display, so do not hard-wrap at 80 chars mid-clause. Do not
  merge lines into flowing paragraphs either. This is the most recognisable
  trait.
- **`since`, not `because`** (38 vs 5 in the corpus). `thus`, `anyways`,
  `Otherwise`, `Still` also recur. Never `tbh`, `imo`, `afaik`, `LGTM`, `nit:`.
- **Backtick every identifier, file, path**: `resolve_head`,
  `menu_functions.rs::333`. Reference issues bare: `#1100`.
- **No em-dashes**, no emoji. `!` only on thanks (`Nice!`, `Thanks!`).
- Sentence case, but lowercase `i` slips in ("i think", "i missed that").
  Light typos are in-voice, do not over-polish.
- **Disclose LLM use**, and ask others to.

## Review comments and replies

- **~3 lines, ~44 words median.** One-liners are fine (`Yeah agreed.`,
  `fixed in #1100`). Go long only for real design analysis.
- Open straight into the point, or `Hey there,` / `Hey @user,`. Never
  "Great work!" boilerplate. Praise is specific and rides with the verdict.
- **Pushback opens `Hmm`. Agreement opens `Yeah`.**
- **Close with a landing verdict**: `Fine to land.` /
  `Happy to land once those are in.` / `Otherwise good to land once tests are in.`
- Severity by framing, not labels:
  - blocker: `Without a plan to mitigate this no way we can merge this.`
  - changes: `Two small things before we land it:` plus short bullets
  - nit: bare sentence, no ceremony
  - suggestion: a question (`Maybe add a positive test for X?`)
- Disagree directly, then release the pressure:
  `I don't want to block the bug fix. If the consensus is to stay flat, this is fine.`
- Hedge with `I think` / `feels` / `seems`; invite correction (`right?`).
- Own reversals loudly (`Walking back the parameterization I suggested.`
  ... `Sorry for the churn.`). Empathy before a "no".
- `@name` on its own line, body underneath.

## PR bodies

- Conventional-commit title, scope in parens, `!` for breaking:
  `feat(vi)!: visual mode on a unified Cursor + rest-policy model`.
- **The target repo's own template wins.** Before drafting, check
  `.github/pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md` at the root or
  under `docs/`, any `.github/PULL_REQUEST_TEMPLATE/` directory, and whatever
  `CONTRIBUTING.md` says about PRs. Fill that template's headings and tick its
  checklists; the voice rules here apply inside it.
- **Fall back to reedline's template** when the repo ships none, comments
  stripped (upstream lives at
  `nushell/reedline/.github/pull_request_template.md`):

  ```markdown
  ## Summary

  ### Before

  ### After

  ## Additional notes
  ```

  `Summary` is mandatory: motivate the PR, say how you arrived at this
  solution, and state the public-API or observable-behavior impact explicitly,
  including when there is none (`No public API change (all pub(crate)).`).
  `Before` and `After` describe behavior, function or implementation on each
  side of the change; drop either heading when it does not apply. `Additional
  notes` is optional and carries issue links (`closes #123`, `fixes #456`).
- Add `##` sections on top of whichever skeleton you landed on when the change
  wants them: `What`, `How`, `Motivation`, `Behavior Changes`, `Notes for
  Reviewers`, `Where to look`, `Testing`, `Out of scope`, `Attributions`. A
  skeleton is a floor, so keep its headings and extend past them.
- **Bold-lead bullets** for vocabulary; tables for orientation; fenced `rust`
  blocks to show a proposed signature rather than describing it.
- **Route reviewer attention**: `**Scrutinize** (densest invariants): ...` /
  `**Skim**: ... (pure bool->enum rename)`.
- Always state test status concretely, plus `Out of scope` bullets.
- Personal asides are welcome (`This is the last large PR from my side I
  promise...`).
- Credit people by name at the end, and **close on `Co-Authored-By:` trailers
  alone**: human co-authors first, then the same Claude trailer the commits
  carry (`commit-writer`), each on its own line after a blank line. Those
  trailers are the whole footer, and the only LLM disclosure the body needs:
  drop the "🤖 Generated with Claude Code" line and its link.
