# Glossary format

`prose-glossary.md` lives at the document root, next to the sources, so the
author can edit it and commit it with the document. Keep the section names and
table columns exactly as below: `scripts/term-drift.sh` parses the Terms table.

In every table, `Where` is `file:line`. A `?` after a canonical form marks a
close call for the author to decide.

```markdown
# Glossary

Status: draft | locked
Acronym convention: once per document | once per chapter

## Terms

| Canonical | Variants | Where |
|---|---|---|
| sample | specimen; probe | ch2.typ:14, ch5.typ:88 |

## Symbols

| Symbol | Meaning | Defined at |
|---|---|---|

## Abbreviations

| Abbreviation | Expansion | First expanded | First used |
|---|---|---|---|

## Decompositions

| Name | Members | Where |
|---|---|---|

## Tense

| Chapter | Results narrated in |
|---|---|

## Conflicts

- One line per conflict: what, where, and the proposed resolution.
```

`Variants` is a semicolon-separated list of the exact surface forms seen. The
drift script matches each variant as a case-insensitive whole word, so list
inflected forms that differ in more than a plural `s` separately.
