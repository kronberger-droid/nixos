---
name: prose-sweep
description: Sweep a whole thesis or long document for prose quality and cross-chapter consistency, one subagent per chapter, edits in place under git.
when_to_use: >-
  When the user wants a whole thesis, paper, or multi-file document swept for
  prose, AI tells, or consistency of terms, notation, abbreviations, and tense
  across chapters. A single passage or section goes to scientific-writing.
argument-hint: [path-or-glob] [sweep|consistency]
user-invocable: true
allowed-tools: Read Write Edit Grep Glob Bash Agent Skill
---

# Prose sweep

Document-scale layer over `scientific-writing`. That skill owns the sentence
rules and the claim-fidelity invariant; this one owns the scale: splitting the
document into chapters, briefing one subagent per chapter, and catching what a
per-paragraph pass cannot see (a term that drifts between chapter 2 and chapter
5, a symbol reused with a new meaning, an abbreviation defined twice).

Prose only. Markup, math, code, labels, references, citation keys, comments,
and URLs pass through byte for byte, whatever the markup language.

## Modes

- **sweep** (default): line pass on every chapter, edits in place.
- **consistency**: build a glossary across all chapters, have the user lock
  it, then unify against it.

For a full treatment run **consistency first**: the locked glossary feeds every
sweep subagent, so terminology is decided once instead of per chapter. The
author commits (or restores) the unification edits before the sweep starts,
since the sweep needs a clean tree too.

## Preconditions

Both modes edit in place. The safety net is git, so check it before anything
else:

1. The files in scope are tracked in a git repository.
2. `git status --porcelain -- <files>` prints nothing.

If either fails, stop and tell the user what is dirty or untracked. The in-place
contract rests on `git diff` and `git restore` being able to show and undo every
change; on a dirty tree they cannot separate the sweep's edits from the
author's. This replaces `scientific-writing`'s "ask before overwriting".

Then establish the **chapters**: one file per chapter when the document is
split that way; otherwise the top-level headings of the single file, as line
ranges. Read the first chapter and write down the concrete markup constructs
this document uses (function calls, math delimiters, label and reference
syntax, citation syntax, comment syntax). That list goes into every brief as the
**passthrough** set.

## References

Loaded on demand; none of them belongs in your context before its step needs it.

| Source | Holds | Read by |
|---|---|---|
| `scientific-writing` skill | Line rules, tense, German-L1 interference, claim fidelity | every sweep subagent |
| `references/humanizer.md` | AI-writing patterns §1–§26 | every sweep subagent |
| `references/mechanical.md` | Greppable rules the two above lack | every sweep subagent |
| `references/semantic.md` | Reader-judgment checks, split per chapter vs. cross-chapter | sweep subagents (their part); consistency mode |
| `references/compression.md` | Length-cutting operations | only when the user asks to cut length |
| `references/glossary-template.md` | Glossary file format | consistency mode |
| `references/elements-of-style.md` | Strunk 1918, about 12k tokens | on a specific usage or composition question |

`humanizer.md` is the standalone `humanizer` skill's own file. Inside a sweep,
use its pattern sections (A to F and "When not to act") and this skill's
workflow and output; its "How to work" and "What to return" sections are for
standalone use.

`elements-of-style.md` is read by section, never whole: `grep -n '^## '` it for
the line numbers, then read only the section the question needs (III for
composition, V for a misused word or expression).

Scripts, run from inside the document's repository:

- `scripts/mechanical-grep.sh FILE...` prints hits per category with counts.
- `scripts/term-drift.sh GLOSSARY FILE...` prints every non-canonical variant.
- `scripts/fidelity-check.sh FILE...` lists numbers and markup tokens removed
  by the uncommitted diff without reappearing in the same hunk.

## Precedence

Where sources disagree, the higher rule wins. The known clashes are settled here
so no subagent relitigates them:

1. **Claim fidelity** from `scientific-writing` outranks everything: numbers,
   units, citations, hedge level, scope.
2. **`scientific-writing`** outranks every imported reference:
   - `significant` keeps its statistical sense and is replaced elsewhere.
     Mechanical's adjective list does not cover it.
   - Voice follows `scientific-writing`'s voice rule. Passive methods prose
     stays passive. Strunk rule 10 and humanizer §11 are weak signals only.
   - Hedging calibrated to the evidence stays. Humanizer §9 collapses
     *stacked* qualifiers to one, and that is all.
   - Headings stay topical, as thesis convention expects.
3. **The voice sample** sets dash rate, sentence length, and transitions
   (humanizer's Voice section). Without one, the register is neutral and plain,
   and dashes are thinned to the places where a dash is the clearest
   punctuation.
4. Humanizer, then `mechanical.md`, then `semantic.md`, then Strunk.

## Voice sample

Before dispatch, ask the user for a passage they wrote themselves, without AI
help, ideally from this document: a file and line range is enough. Pass it to
every subagent. If they have none, say that the sweep runs in the neutral
register and continue.

## Sweep mode

1. Run the preconditions. Load `prose-glossary.md` from the document root if it
   exists; its canonical forms are binding.
2. Dispatch one `general-purpose` subagent per chapter, all in one message.
   Parallelism stops at the file boundary: chapters that share a file run one
   after another, since concurrent edits to one file overwrite each other.
   Each brief carries:
   - the chapter (file, and line range when it shares a file);
   - the passthrough set, verbatim;
   - the voice sample, or the note that there is none;
   - the glossary path, when it exists;
   - absolute paths to this skill's `references/` and `scripts/`;
   - the task below.

   > Load the `scientific-writing` skill and run its line pass on
   > your chapter, editing the file in place with Edit. Read
   > `references/humanizer.md` (sections A to F and "When not to act") and
   > `references/mechanical.md`, and the per-chapter checks in
   > `references/semantic.md`. Follow the precedence list you were given.
   > Touch prose only: every construct in the passthrough set stays byte for
   > byte. Use the glossary's canonical forms. Structure stays: no moved
   > sentences across paragraphs, no merged or split paragraphs. Where meaning
   > is unrecoverable or a number is missing, leave the sentence and ask.
   >
   > Done means: every paragraph in your range read, and every hit from
   > `scripts/mechanical-grep.sh <file>` either fixed or justified in one line.
   >
   > Return: the change list grouped by kind with counts (`Tense: 6 result
   > sentences to past`), individual entries for changes the author might
   > reverse, the mechanical hit counts before and after, questions with line
   > numbers, and **drift suspects**: terms, symbols, or abbreviations that
   > look like they mean something else elsewhere in the document.
3. When every subagent has returned, run `scripts/fidelity-check.sh` over the
   chapter files. Each token it prints is either justified by the change list
   or restored by you. Then read the diff hunks once for markup that changed.
4. Report: per-chapter change lists, the merged questions, the drift suspects
   (offer consistency mode if there are any), and `git diff --stat`. Leave the
   changes uncommitted for the author to review with `git diff` and undo with
   `git restore <file>`.

## Consistency mode

1. Run the preconditions.
2. **Extract.** Dispatch one subagent per chapter, read only, no edits. Each
   reads `references/semantic.md` (the cross-chapter checks) and
   `references/glossary-template.md`, and returns for its chapter: load-bearing
   terms with every surface form used, symbols with meaning and line,
   abbreviations with where they are expanded and first used, decompositions
   ("three regimes", "four stages") with their members, and the tense results
   are narrated in.
3. **Merge** the returns into `prose-glossary.md` at the document root, in the
   template's format. Pick the dominant form as canonical and mark it `?` where
   the choice is close. Fill the Conflicts section: a symbol with two meanings,
   an abbreviation expanded twice or never, used before its expansion, a
   decomposition whose count or members differ between chapters, tense that
   shifts between chapters.
4. **Lock.** Stop and hand the glossary to the user. It becomes the locked
   source of truth only once they have edited or approved it; terminology is
   the author's call.
5. **Unify.** Run `scripts/term-drift.sh prose-glossary.md <files>`, then apply
   the locked glossary in place, one subagent per file:
   - term variants become the canonical form, adjusting articles and agreement;
   - an abbreviation keeps its first expansion, later expansions go, and a use
     before the first expansion gets the expansion moved there;
   - symbol conflicts and decomposition mismatches are flagged with file and
     line, never edited, since renaming notation changes the mathematics;
   - an abbreviation the document never expands becomes a question.
6. Run `scripts/fidelity-check.sh`, then report as in sweep mode, plus the
   flagged conflicts.
