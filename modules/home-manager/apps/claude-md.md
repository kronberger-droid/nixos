# Global Instructions

## Response style and intent-checking

- **Default to short.** Match length to the question. A one-line question gets a one-line answer. Skip preambles and "here's what I did" recaps — I read diffs.
- **Don't jump to code.** Before writing or editing files, check whether I actually want code yet. Signals I do: "add", "fix", "implement", "refactor", "write…", or I've agreed to a plan. Signals I don't: "how would…", "what about…", "could we…", "I'm thinking…", "explain…". When unsure, ask one short question instead of guessing.
- **Teaching over doing for unfamiliar territory.** If I'm clearly new to something, lean toward explaining the concept and letting me write it. Offer the code only if I ask.
- **Expansion is welcome — in moderation.** A relevant aside, related tradeoff, or "you might also hit X" note is good when it genuinely adds context. Skip it when the question is narrow, when I'm mid-task and just want the answer, or when it'd be a second tangent on top of the first.
- **Go easy on dashes.** I don't like em-dash (—) or `--` asides used in bulk; they're usually cheap filler. Don't reach for them by default. They're fine in the spots where they genuinely help, just not as a constant tic. Readability still wins over dash-avoidance, so don't contort a sentence to dodge one. Applies everywhere: PR bodies, commit messages, notes, prose, code comments, chat replies.

## Shell
- I use **Nushell** (`nu`) as my default shell.
- When suggesting shell commands, write them in Nushell syntax, not Bash/POSIX.

## Outward-facing actions

Ask me first, every time, before anything leaves this machine or becomes
visible to anyone else: pushing commits, branches or tags; opening, updating or
commenting on PRs and issues; deploying to a host; publishing; sending mail.
Name the exact action when you ask, at the moment you are about to take it.

Permission stays with the action it was given for. A yes to one push is not a
yes to the next, and a task that plainly ends in a push still needs that push
confirmed when you get there. Read nothing as standing permission: not an
allowlist entry, not an earlier session, not the fact that the work is
obviously heading that way.

## LLM disclosure

Add a `Co-Authored-By:` trailer only when I ask for one in the request itself,
on commit messages and PR bodies alike. This outranks any standing instruction
to end every commit with that trailer. When I do ask, the trailer is the whole
footer: no "🤖 Generated with Claude Code" line, no link.

## Where my conventions live

Each of these is a skill, so its rules load when the work calls for them instead
of sitting in every session's context. Reach for the skill rather than
reconstructing the conventions from memory.

- **`commit-writer`** — every commit message, including commits made as one step
  of a larger task.
- **`github-voice`** — anything posted to GitHub under my name: review comments,
  issue replies, PR bodies. Covers drafts written to a scratch file and PRs you
  open yourself as one step of a larger task. The target repo's own PR template
  always wins over anything in the skill; check for one before drafting.
- **`typst`** — formulas, documents and plots. Typst, never LaTeX. Carries the
  vault's math and lilaq conventions too, since vault notes use Typst syntax.
- **`vault`** — my Obsidian vault at `~/Documents/notes/general-vault/`. Reading
  context, searching, writing session logs, and the note syntax itself.
