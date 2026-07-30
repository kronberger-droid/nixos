---
name: scientific-writing
description: Correct, tighten, and restructure scientific prose in English.
when_to_use: >-
  When the user wants scientific or academic text corrected, proofread, tightened,
  rewritten, or restructured — abstracts, lab reports, protocols, theses, papers,
  or a section that reads badly.
argument-hint: [file-or-text] [line|structure]
user-invocable: true
allowed-tools: Read Write Edit Grep Glob
---

# Scientific writing

The text belongs to the author. You sharpen how it reads; the author owns what it
says.

## Claim fidelity

The one invariant, held across every pass: **every claim in your output traces to
a claim in the input, at the same strength.**

Concretely, carry these through untouched unless the user asks otherwise:

- Numbers, units, uncertainties, symbols, and variable names — verbatim.
- Citations — verbatim. A citation you did not receive is one you do not add.
- Hedge level. `suggests` stays `suggests`; it does not become `shows`. `may
  contribute` does not become `contributes`.
- Scope. `in our sample` stays; `at 300 K` stays.

When a sentence is unclear enough that tightening it would require deciding what
it means, leave it and flag it as a question. A guessed meaning reads fluently
and is worse than an awkward sentence, since the author can no longer see the
problem.

## Pick the pass

Two passes, deliberately separate, because they invite different amounts of
damage. Name the one you are running in your first line of output.

- **Line pass** — sentence-level correction and tightening. Structure, section
  order, and paragraph boundaries stay exactly as they are.
- **Structure pass** — reorganisation: what belongs in which section, paragraph
  boundaries, order of argument. Sentences get rewritten in service of the move.

Default to the **line pass**. Run the structure pass when the user asks for one,
or when a line pass would be rearranging deck chairs — in which case say so and
ask, rather than silently escalating. Running both at once makes the diff
unreviewable, which is the real cost.

---

## Line pass

### Tense

English scientific convention, by what the sentence is about:

| Subject | Tense | Example |
|---|---|---|
| Established knowledge | present | `The Debye model predicts $C_V prop T^3$.` |
| What you did | past | `We heated the sample continuously.` |
| What you found | past | `The measured value was 385(4) J/(kg K).` |
| What a figure/table does | present | `Figure 3 shows the residuals.` |
| Interpretation of results | present | `This indicates a phonon contribution.` |

The common slip is narrating results in the present (`the value is 385`), which
quietly upgrades one measurement into a general fact.

### Tighten

Cut what carries no information. The dense offenders:

- **Throat-clearing openers.** `It should be noted that the drift is small.` →
  `The drift is small.` Same for `It is important to mention`, `In this section
  we will`, `As can be seen`.
- **Nominalisations.** `performed a measurement of` → `measured`. `led to an
  improvement in` → `improved`. Verbs carry the action.
- **Empty intensifiers.** `very`, `quite`, `rather`, `significantly` used
  non-statistically, `clearly`, `obviously`. If the reader can see it, the word
  is redundant; if they cannot, the word is a claim without evidence.
- **Doubled meaning.** `completely eliminated`, `absolutely necessary`,
  `end result`, `in order to` → `to`.
- **Stacked prepositions.** `the value of the slope of the fit of the data` →
  `the fitted slope`.

Tightening has a floor: stop when the next cut would remove a qualification the
author put there on purpose.

### Precision

- **Comparatives need a referent.** `The signal was higher` → higher than what.
- **Quantify vague size words.** `a small offset` → `a 2 mV offset`, when the
  number exists in the text. When it does not, flag it rather than invent it.
- **`significant` is statistical.** Reserve it for that, and use `substantial` or
  a number elsewhere.
- **One term per concept.** If the text calls it `sample`, `specimen`, and
  `probe` in three paragraphs, pick the dominant one and make it uniform — then
  say in the change list that you did, since terminology is the author's call.
- **Units and numbers.** Digit, thin space, unit (`5 mV`). Ranges keep the unit
  on both ends when ambiguity is possible. Uncertainties match the precision of
  the value (`385(4)`, not `385.27(4)` from a 4-unit uncertainty).

### Voice

Active where it does not force a fake agent: `We measured`, `The detector
records`. Passive is correct and preferable when the actor is irrelevant or
obvious (`The samples were annealed at 900 K`). Both belong in the same document;
mechanically converting one to the other is not an improvement.

### German-L1 interference

The author writes English as a German speaker. These recur and are invisible to
a spell checker:

- **False friends.** `eventually` (≠ *eventuell*, use `possibly`), `actual` (≠
  *aktuell*, use `current`), `sensible` (≠ *sensibel*, use `sensitive`), `become`
  (≠ *bekommen*, use `receive`), `control` (≠ *kontrollieren* meaning check).
- **`since` reading as temporal.** In German-influenced English `since` gets used
  causally at the start of long sentences where an English reader parses it as
  *from the time that*. Keep the causal `since` for short clauses; use `because`
  when the sentence is long enough that the reader commits to the wrong reading.
  (In the author's own GitHub prose `since` is a deliberate stylistic marker —
  leave it alone there; this applies to formal scientific text.)
- **Noun stacking.** German tolerates `Messwertaufnahmegenauigkeit`; English
  needs `the accuracy of the recorded measurements`. Break chains of three or more
  stacked nouns.
- **`respectively` as a catch-all.** It pairs list to list in order
  (`A and B were 3 and 5 K, respectively`) and does nothing else. Where it means
  *in each case*, say that.
- **Comma before `that`.** German sets a comma before *dass*; English does not
  before a restrictive `that`.
- **Uncountables.** `information`, `research`, `evidence`, `equipment` take no
  plural `s`.
- **Position of `also`.** `Also the temperature was recorded` → `The temperature
  was also recorded`.

---

## Structure pass

### Section content

Check each claim sits in the section that owns it. The frequent misfilings:
method detail stranded in Results, interpretation smuggled into Results,
new results appearing for the first time in the Discussion, and the Introduction
carrying theory that belongs in its own section.

| Section | Owns |
|---|---|
| Abstract | Question, approach, principal result *with its number*, one implication |
| Introduction | Context, the gap, what this work does about it |
| Theory | Derivations and models the reader needs to follow the analysis |
| Method | Enough for a competent reader to repeat the work |
| Results | What was observed, without arguing for its meaning |
| Discussion | Interpretation, comparison to literature, limitations |
| Conclusion | What is now known that was not before |

### Paragraphs

- **One claim per paragraph.** Two claims means two paragraphs, or one is
  support for the other and should be subordinated explicitly.
- **Topic sentence first.** The reader should be able to read only the first
  sentence of each paragraph and get the argument. This doubles as a diagnostic:
  extract the first sentences and see whether they form a coherent sequence. If
  they do not, the problem is the structure, not the prose.
- **Given–new order.** Open a sentence with information already in the reader's
  head, and put the new information at the end. This is what makes paragraphs
  feel like they flow, and its absence is usually what "reads badly" means.
- **Explicit links between paragraphs**, carrying the logical relation
  (`This leaves open whether…`, `The same argument fails when…`) rather than a
  bare `Furthermore`.

### Moving text

When you move a passage, move it whole and adjust only what the new position
requires — tense, the referent of a pronoun, a forward reference that is now
backward. A move plus a rewrite in one step hides both.

---

## Output

Return, in this order:

1. **The pass you ran**, one line.
2. **The edited text**, complete and ready to use. For a structure pass, keep the
   section headings visible so the reordering is legible.
3. **The change list** — grouped by kind, not one entry per comma. `Tense: 6
   result sentences moved to past.` `Cut: 4 throat-clearing openers.` Spell out
   individually only the changes the author might want to reverse, and every
   place you unified terminology.
4. **Questions**, where a sentence's meaning was unrecoverable or a number was
   missing. These are the flags you refused to guess at.

Work on the text in the conversation unless the user points you at a file. When
they do, read it, then ask before overwriting — an edit pass on a draft is not
obviously wanted in place.
