# Global Instructions

## Response style and intent-checking

- **Default to short.** Match length to the question. A one-line question gets a one-line answer. Skip preambles and "here's what I did" recaps — I read diffs.
- **Don't jump to code.** Before writing or editing files, check whether I actually want code yet. Signals I do: "add", "fix", "implement", "refactor", "write…", or I've agreed to a plan. Signals I don't: "how would…", "what about…", "could we…", "I'm thinking…", "explain…". When unsure, ask one short question instead of guessing.
- **Teaching over doing for unfamiliar territory.** If I'm clearly new to something, lean toward explaining the concept and letting me write it. Offer the code only if I ask.
- **Expansion is welcome — in moderation.** A relevant aside, related tradeoff, or "you might also hit X" note is good when it genuinely adds context. Skip it when the question is narrow, when I'm mid-task and just want the answer, or when it'd be a second tangent on top of the first.
- **Go easy on dashes.** I don't like em-dash (—) or `--` asides used in bulk; they're usually cheap filler. Don't reach for them by default. They're fine in the spots where they genuinely help, just not as a constant tic. Readability still wins over dash-avoidance, so don't contort a sentence to dodge one. Applies everywhere: PR bodies, commit messages, notes, prose, code comments, chat replies.

## GitHub writing style

When drafting PR bodies, review comments, or issue replies **as me**, match this.
Derived from ~144 of my comments and 16 PR bodies on `nushell/reedline`.

Only the directives live here. The full evidence base (verbatim quotes per rule,
the fuller short-form/long-form breakdown) is at
`~/Documents/notes/general-vault/_context/claude/github-writing-style.md` —
read it when you need to calibrate phrasing closely or the rules below feel
underspecified.

### Both registers
- **One clause per line, soft-wrapped.** Break at sentence/idea boundaries only,
  never at a column limit. A clause runs as long as it needs and GitHub wraps it
  for display, so don't hard-wrap at 80 chars mid-clause. Don't merge lines into
  flowing paragraphs either. This is the most recognisable trait.
- **`since`, not `because`** (38 vs 5 in my corpus). `thus`, `anyways`,
  `Otherwise`, `Still` also recur. Never `tbh`, `imo`, `afaik`, `LGTM`, `nit:`.
- **Backtick every identifier, file, path**: `resolve_head`,
  `menu_functions.rs::333`. Reference issues bare: `#1100`.
- **No em-dashes**, no emoji. `!` only on thanks (`Nice!`, `Thanks!`).
- Sentence case, but lowercase `i` slips in ("i think", "i missed that").
  Light typos are in-voice, don't over-polish.
- **Disclose LLM use**, and ask others to.

### Review comments and replies
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

### PR bodies and commit messages
- Conventional-commit title, scope in parens, `!` for breaking:
  `feat(vi)!: visual mode on a unified Cursor + rest-policy model`.
- `##` headers chosen per PR, not a fixed template: `Summary`, `What`, `How`,
  `Motivation`, `Behavior Changes`, `Notes for Reviewers`, `Where to look`,
  `Testing`, `Out of scope`, `Attributions`.
- **Bold-lead bullets** for vocabulary; tables for orientation; fenced `rust`
  blocks to show a proposed signature rather than describing it.
- **Route reviewer attention**: `**Scrutinize** (densest invariants): ...` /
  `**Skim**: ... (pure bool->enum rename)`.
- Always state test status concretely, and API/behavior impact
  (`No public API change (all pub(crate)).`), plus `Out of scope` bullets.
- Credit people by name at the end; preserve `Co-authored-by:`.
- Personal asides are welcome (`This is the last large PR from my side I
  promise...`).

## Shell
- I use **Nushell** (`nu`) as my default shell.
- When suggesting shell commands, write them in Nushell syntax, not Bash/POSIX.

## Obsidian Notes
- My vault is at `~/Documents/notes/general-vault/`
- Formulas use **Typst syntax**: inline `$...$`, display `$$...$$`
- Graphs use ` ```lilaq ... ``` ` code blocks (Typst's lilaq plotting library)
- Standard Markdown headings (`##`, `###`), bold (`**...**`), italic, and `---` separators

## Typst Syntax Reference

### Math Mode
- Inline: `$x^2$`, Display: `$ x^2 $` (spaces inside `$` make it block-level)
- Fractions: `(a + b) / (c + d)` — parentheses control grouping
- Function form: `frac(a, b)` also works
- Subscripts/superscripts: `x_1`, `x_(i+1)`, `x^2`, `x^(2n)`
- Summation: `sum_(i=0)^n`, Product: `product_(i=0)^n`
- Integral: `integral_a^b f(x) dif x`
- Partial derivative: `(partial f) / (partial x)`, `(partial^2 f) / (partial x^2)`
- Evaluated-at bar: `bar.v_(x=0)` for the vertical bar with subscript
- Greek: `alpha`, `beta`, `delta`, `epsilon`, `sigma`, `pi`, `infinity`
- Operators: `dot` (multiply), `cross`, `plus.minus`, `arrow.double` (implies)
- Text in math: `"text here"` (in quotes)
- Vectors: `vec(x_1, x_2, x_3)`, `arrow(v)` for vector arrow
- Matrices: `mat(1, 2; 3, 4)` — semicolons separate rows
- Cases: `cases(1 "if" x > 0, 0 "else")`
- Alignment in multi-line: `$ a &= b \ &= c $`
- No `\boxed{}` — use `#block(stroke: 0.5pt, inset: 8pt)[$ ... $]` instead
- `dif` for the upright differential d
- Escaping `/` in text: use `\/` to prevent fraction interpretation

### General Typst
- Import packages: `#import "@preview/package:version" as alias`
- Bold: `*bold*`, Italic: `_italic_`
- Headings: `= H1`, `== H2`, `=== H3`
- Labels/refs: `<label>` and `@label`
- Code: `` `inline` `` or ` ```lang block``` `
- Lists: `- item` or `+ numbered`
- Functions: `#let f(x) = { ... }`
- Loops: `#for item in list { ... }`
- Conditionals: `#if cond { ... } else { ... }`
- Content blocks: `[content]`, Code blocks: `{ code }`
- Set rules: `#set text(size: 12pt)`, Show rules: `#show heading: set text(blue)`
- Page setup: `#set page(flipped: true)` for landscape

### Lilaq (lq) Plotting Library
- Import: `#import "@preview/lilaq:0.5.0" as lq`
- Basic plot: `lq.diagram(xlabel: $x$, ylabel: $y$, lq.plot(xs, ys))`
- Plot options: `mark: none`, `stroke: 1.5pt + red`, `label: [text]`
- Bar chart: `lq.bar(centers, heights, width: w, label: [text])`
- Multiple curves: spread an array into `lq.diagram`:
  ```
  lq.diagram(
    ..data.map(d => lq.plot(d.x, d.y, mark: none, label: [...])),
    legend: (position: top + right),
  )
  ```
- Legend: `legend: (position: top + right)`
- Axis limits: `xlim: (0, 10)`, `ylim: (0, 1)`
- Sizing: `width: 100%`, `height: 80%`
- Title: `title: [Plot Title]`

## Vault Context

My Obsidian vault is at `~/Documents/notes/general-vault/`. Use the `/vault` skill to interact with it — read notes, search, write session logs, and load context. The skill uses Claude's built-in file tools (Read, Write, Edit, Grep, Glob) directly on the vault files.
