# Reader-judgment checks

Adapted from `author_profile/gate_semantic.md` in SNL-UCSB/paper-writing-skill
(MIT, Copyright (c) 2026 Arpit Gupta; see `LICENSE-paper-writing-skill`).
Kept S1 to S14 and S18, reworded for a thesis and split by mode; dropped the
provenance, requirement-table, figure, venue, and closure-loop checks, which
belong to the paper pipeline.

These are the failures a grep cannot catch. Read with a **fresh reader's** eyes:
someone competent in the field who has not seen this document. Each finding is
file, line, the problem, and a concrete fix. MAJOR means a reader is confused;
CRITICAL means the argument is incoherent.

## Per chapter (sweep subagents)

**Define before use (MAJOR).** Every domain term, acronym, and coined construct
is defined in plain words before its first argumentative use. A gloss that is
itself jargon fails; gloss the gloss.

**Parse accessibility (MAJOR).** Common words can still form an unparseable
sentence. Look for:
- reduced relative clauses with dropped `who`/`that` (`a sample annealed is
  stable` → `a sample that is annealed is stable`);
- opaque idioms a literal reader cannot decode (`earns its keep`);
- one coined word carrying several meanings;
- a definition, a claim, and a hedge packed into one breath.

**Referents (MAJOR).** Every `it`, `this`, `these`, `that <noun>` resolves to
one antecedent; name it when it does not. Separate the thing from the process
(`collecting the data`, not `the data`).

**Deliver the noun (MAJOR).** A paragraph that promises to define or explain X
contains one sentence that states X. If none does, that is the finding.

**Gloss pile-ups (MAJOR).** Two or more parenthetical glosses or a chain of
appositives in one sentence. One idea per sentence; move each gloss to its
term's first use.

**Dangling modifiers (MAJOR).** A leading participial phrase refers to the
grammatical subject. `Using this fit, the gap was estimated` dangles.

**Hedge scan (MAJOR).** For each empirical or causal universal (`X is Y`, `X
causes Y`) ask whether the evidence in the text supports "always". Where it
supports "typically" or "in our samples", flag it with the hedge the evidence
supports. Never strengthen a hedge.

## Cross-chapter (consistency mode)

**Term order (MAJOR).** In a chain of concepts, each is introduced before it is
leaned on. List coined terms by first appearance across the whole document; a
use in chapter 2 of a term defined in chapter 4 is a finding.

**Acronyms (MAJOR).** Expanded once, at the first use in the document (or once
per chapter, if the document's own convention is that; record which in the
glossary), abbreviated after.

**Gloss once (MAJOR).** A term is glossed at first use and not re-glossed in
later chapters, unless the document's convention re-glosses per chapter.

**One word per concept (CRITICAL).** Synonym clusters for one concept
(`sample`/`specimen`/`probe`; `keep`/`retain`/`preserve`) drift across chapters
written months apart. One canonical form each; genuine distinctions stay.

**Decomposition invariance (CRITICAL).** When the document splits something into
parts (three regimes, four stages), every chapter that lists them uses the same
members, count, and names.

**Non-duplication (CRITICAL).** A result or number is claimed in its home
chapter; elsewhere it is referenced. The same result stated with two different
values is the worst case of this.

**Thesis tie (CRITICAL).** Every chapter's claims connect to the research
question as the introduction states it, in the same words. Flag a chapter that
re-phrases the research question, or opens a thread the question does not
reach.
