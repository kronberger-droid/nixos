# Mechanical rules

Adapted from `author_profile/gate_mechanical.md` in SNL-UCSB/paper-writing-skill
(MIT, Copyright (c) 2026 Arpit Gupta; see `LICENSE-paper-writing-skill`).
Changed: the dash, passive-voice, and `significant` rules defer to the
precedence list in `SKILL.md`; rules that `humanizer.md` or `scientific-writing`
already state are pointers here instead of copies; greps take file arguments
and live in `scripts/mechanical-grep.sh`.

These are the checks a regex can find. A hit is a candidate, not a verdict:
read it in context, then fix it or justify keeping it in one line. Report the
counts from the script, not "audited".

## Owned elsewhere

The script greps for these too; the rule text lives at the source.

| Category | Rule lives in |
|---|---|
| `dash` | `SKILL.md` precedence 3; humanizer §8 |
| `antithesis` | humanizer §1 (keep the negation when it carries a fact) |
| `closer` | humanizer §2, §3 |
| `ai-words` | humanizer §12 |
| `significant` | `scientific-writing` Precision |
| `wordiness` | `scientific-writing` Tighten |
| `passive` | `scientific-writing` Voice; weak signal only |
| `l1` | `scientific-writing` German-L1 interference |

## Rules held here

**Intensifiers (`intensifier`).** `in effect`, `in a sense`, `in essence`,
`truly`, `genuinely`, `simply`, `essentially`, `fundamentally` as filler,
`really`, `in fact`, `indeed`, `actually`, `exactly`, `precisely because`.
Delete, or replace with the precise referent.

**Quality adjectives (`adjective`).** `novel`, `impressive`, `promising`,
`comprehensive`, `robust` (figurative), `powerful`, `state-of-the-art` (except
naming a specific prior system), `paradigm`, `leverage` (verb), `utilize`.
They assert quality without stating it: replace with a number, a mechanism, or
nothing. `significant` and `substantial` follow `scientific-writing`.

**Throat-clearing openers (`opener`).** A sentence starting with `Moreover`,
`Furthermore`, `Additionally`, `Notably`, `Importantly`, `Ultimately`,
`Crucially`, `That said`, `It is worth noting that`, `It should be noted that`.
Start with the claim. Keep a connective only when a real logical move follows
it, and then prefer the one that names the move (`This leaves open whether`).

**Content-free openers (`opener`).** `In this chapter, we`, `In this section,
we describe`. Lead with what the section shows.

**Metaphor filler (`metaphor`).** `under the hood`, `draws its power from`,
`where X meets Y`, `the machine that`. Name the mechanism.

**Hype verbs (`hype`).** `unlocks`, `powers`, `promises to`, `stands to`, `is
poised to`, `opens the door to`, `has the potential to`, `keeps X from Y`,
`stands in the way of`. Each hides a mechanism; state it, or grade the claim.

**Weak qualifiers (`qualifier`).** `rather`, `very`, `pretty`, `quite`,
`somewhat`, `fairly`, `certainly` as emphasis, `little` as intensifier. Use a
stronger word or a number. A qualifier that carries the author's calibrated
uncertainty is a hedge, and hedges stay.

**Coined adverbs and ordinals (`ordinal`).** `thusly`, `overly`, `firstly`,
`secondly`, `thirdly` (use `first`, `second`, `third`), the `-wise` suffix
(`costwise`).

**Exclamation marks (`exclaim`).** None in technical prose. Rhetorical
questions: at most one, in an introduction.

**Pompous words (`pompous`).** `finalize`, `-oriented`, `meaningful`,
`insightful`, `possess` (use `have`), `impact` as a verb (use `affect`),
`currently` with a present-tense verb.

**Showy verbs (`verb`).** Prefer the plain word unless the fancy one is domain
jargon with no plain equivalent (`amortize`, `traverse`). `orchestrate` →
`coordinate`, `harness` → `use`, `forge` → `build`, `weave` → `combine`,
`usher in` → `start`, `delve into` → `examine`, `grapple with` → `address`,
`unpack` (figurative) → `explain`, `marshal` → `gather`, `anew` → `again`.
Polysemous words (`run`, `surface`, `bind`) are judged by sense, never
replaced wholesale.

**Precision pairs (`pairs`).** Not banned; check each hit for the wrong member:
`affect`/`effect`, `imply`/`infer`, `comprised of` (use `comprises` or
`consists of`), `data is` (plural in most scientific style guides; follow the
document's own consistent choice), `fewer`/`less`, `farther`/`further`,
`that`/`which` (restrictive vs. non-restrictive), `very unique`,
`different than` (use `different from`), adverbial `due to` (use `because of`).
