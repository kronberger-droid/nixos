---
name: vault
description: Read, search, and write notes in the Obsidian vault. Use as dynamic context and memory.
when_to_use: >-
  When working with Obsidian vault notes — reading context, searching for related notes,
  writing session logs, learnings, or decisions. Also use proactively before non-trivial
  tasks to check active projects and preferences.
argument-hint: <action> [query-or-path]
user-invocable: true
allowed-tools: Read Write Edit Grep Glob Agent
---

# Obsidian Vault — Context & Memory

The vault is at `~/Documents/notes/general-vault/`.

## Actions

Determine the action from `$ARGUMENTS` or infer from context:

### `read <path>`
Read a note at the given path (relative to vault root).
- Use the Read tool on `~/Documents/notes/general-vault/<path>`
- If the note contains `[[wikilinks]]`, offer to follow them

### `search <query>`
Search the vault for notes matching a query.
- Use Grep to search note contents: `pattern: "<query>", path: "~/Documents/notes/general-vault/"`
- Use Glob to find notes by filename: `pattern: "**/*<query>*.md", path: "~/Documents/notes/general-vault/"`
- Combine both approaches for thorough results
- Show results with brief context (matching lines or frontmatter)

### `write <path>`
Write or update a note at the given path (relative to vault root).
- Use Write (new note) or Edit (existing note) on `~/Documents/notes/general-vault/<path>`
- Always include YAML frontmatter with `type`, `status`, `tags` fields
- Follow vault conventions (see below)

### `links <path>`
Follow wikilinks from a note to build context chains.
- Read the note, extract all `[[wikilinks]]`
- Use Glob to find the linked notes: `pattern: "**/<link-name>.md"`
- Read and summarize linked notes

### `context`
Load active project context (no arguments needed).
- Read `_context/active-projects.md`
- Read `_context/preferences.md`
- Summarize current priorities

### No action specified
If `$ARGUMENTS` is empty or unclear, ask what the user wants to do.

## When to use proactively

Even without being asked, use this skill:
- **Before non-trivial tasks**: load `_context/active-projects.md` for current priorities
- **When working on a topic**: search for related notes in the vault
- **When you need preferences**: read `_context/preferences.md`

## When to write

- **After significant sessions**: write summary to `_context/claude/session-YYYY-MM-DD-topic.md` with frontmatter `type: session-log`
- **When learning something non-obvious**: append to `_context/claude/learnings.md`
- **When a decision is made**: append to `_context/claude/decisions.md`
- Only write when there's something worth remembering. Don't write noise.

## Vault conventions

- Notes use YAML frontmatter with `type`, `status`, `tags` fields
- Links use `[[wikilinks]]`
- Tags use `#tag` and `#parent/child` format
- Formulas use **Typst syntax**: inline `$...$`, display `$$...$$`
- Graphs use ` ```lilaq ... ``` ` code blocks
- The `_context/` folder is the shared interface between user and Claude
- The `_context/claude/` subfolder is where Claude writes — user reviews in Obsidian
