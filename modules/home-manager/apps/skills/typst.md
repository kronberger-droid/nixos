---
name: typst
description: Write, scaffold, and fix Typst documents, with a compile-until-clean loop.
when_to_use: >-
  When the user wants to create, edit, scaffold, or debug a Typst document (.typ) —
  lab reports, summaries, exam sheets, papers, theses — or hits a Typst compile error
  or layout problem. Also when writing Typst math or lilaq plots inside Obsidian
  vault notes, which use Typst syntax rather than LaTeX.
argument-hint: [file-or-topic]
user-invocable: true
allowed-tools: Read Write Edit Grep Glob Bash mcp__plugin_context7_context7__query-docs mcp__plugin_context7_context7__resolve-library-id
---

# Typst

Typst is a compiler, so correctness is observable. The rule that makes this skill
worth invoking: **hand back only compile-clean Typst.**

## Compile-clean

Every `.typ` you write or edit gets compiled before you report it as done.

```nu
typst compile main.typ
```

Silence means success. Any `error:` means the work is not finished — read the
error, fix it, compile again. Loop until clean. A document that "should work"
but was never compiled counts as unfinished, and saying otherwise is a false
report.

For a document under active iteration, `typst watch main.typ` recompiles on save
and the user can keep a viewer open. Run it in the background, never in the
foreground (it never exits).

Two flags that come up:
- `--root <dir>` when the document reads files above its own directory.
- `--font-path <dir>` for fonts outside the system set. `typst fonts` lists what
  is currently visible; check it before setting a font you are not sure exists,
  since a missing font silently falls back rather than erroring.

## Ground the version first

Typst's syntax and stdlib move between releases, and your priors may be from
either side of a change.

```nu
typst --version
```

As of this writing the system has **0.15.1**. When something that "should work"
fails, suspect a version drift before suspecting yourself, and check the current
docs via context7 (`resolve-library-id` → `typst/typst`) rather than recalling.

## Scaffolding a document

### Project layout

For anything longer than a page, split:

```
report/
  main.typ        # content only
  lib.typ         # #let helpers: data parsing, fits, custom figures
  template.typ    # #let template(doc) = { set rules }; applied via #show
  refs.bib
  data/
```

`main.typ` then opens with `#import "template.typ": template` and
`#show: template`. The user already works this way (see
`134-126_Laboratory-Work-III/Cp/protocol/` for `lib.typ` holding measurement
parsing and linear fits) — follow the existing layout of the project you are in
rather than imposing this one.

### Preamble

This compiles clean on 0.15.1. Adapt, don't copy blindly:

```typst
#import "@preview/physica:0.9.8": *
#import "@preview/unify:0.7.1": num, qty

#set page(paper: "a4", margin: 2.5cm, numbering: "1")
#set text(font: "New Computer Modern", size: 11pt, lang: "en")
#set par(justify: true, leading: 0.65em)
#set heading(numbering: "1.1")
#set math.equation(numbering: "(1)")
#show ref: it => text(fill: blue.darken(20%), it)
```

`set` rules go at the top and apply document-wide. To scope one, wrap the region
in a block or use `#show` with a selector.

### Figures, tables, references

Every floatable thing is a `#figure`; the label goes *after* the closing paren,
and `@label` references it with the right prefix automatically.

```typst
#figure(
  image("data/setup.png", width: 70%),
  caption: [Experimental setup.],
) <fig:setup>

#figure(
  table(
    columns: 3,
    align: (left, center, center),
    table.header[Sample][$T slash "K"$][$c_p slash ("J" "kg"^(-1) "K"^(-1))$],
    [Cu-1], [295.3], [385(4)],
  ),
  caption: [Measured specific heat.],
) <tab:cp>

As @fig:setup shows, ... and @tab:cp lists ...
```

Equations take labels the same way (`$ ... $ <eq:cv>`) and reference as `@eq:cv`.
Prefer `slash` over a raw `/` in math when you mean a unit division, since `/`
builds a fraction.

### Bibliography

```typst
#bibliography("refs.bib", style: "american-physics-society")
```

Cite with `@key` inline, or `#cite(<key>, form: "prose")` when the citation is
the sentence subject. The `style` argument takes a bundled CSL name;
`american-physics-society` is verified working. If a style name errors, it is not
bundled — check the Typst docs for the exact spelling before inventing one.

## Markup and scripting

Markup is terse and whitespace-aware:

```typst
= Heading    == Subheading    === Sub-sub
*bold*   _italic_   `inline code`   #link("https://…")[text]
- bullet     + numbered     / term: definition
```

`#` switches from markup into code, `[...]` is a content block, `{...}` is a code
block. That distinction is behind most confusion: `#let f(x) = [content]` returns
markup, `#let f(x) = { 1 + 2 }` returns a value.

```typst
#let energy(m) = m * 299792458 * 299792458
#for row in data { [- #row.name: #row.value] }
#if n > 0 [positive] else [non-positive]
```

`set` rules change defaults from that point on; `show` rules transform elements.

```typst
#set text(size: 12pt)
#set page(flipped: true)            // landscape
#show heading: set text(fill: blue)
#show raw: set text(font: "JetBrainsMono NF")
```

## Math and physics typesetting

`$x$` is inline; `$ x $` with spaces inside the delimiters is display. In math
mode, bare letters are variables and multi-letter runs need `"quotes"` for text
or explicit spacing.

### Core syntax

| Want | Write |
|---|---|
| Fraction | `(a + b) / (c + d)` — parens control grouping; `frac(a, b)` also works |
| Sub / superscript | `x_1`, `x_(i+1)`, `x^2`, `x^(2n)` |
| Sum / product | `sum_(i=0)^n`, `product_(i=0)^n` |
| Integral | `integral_a^b f(x) dif x` |
| Partial derivative | `(partial f) / (partial x)`, `(partial^2 f) / (partial x^2)` |
| Evaluated-at bar | `bar.v_(x=0)` |
| Upright differential | `dif` (stdlib) or `dd` (physica) |
| Greek | `alpha`, `beta`, `epsilon`, `sigma`, `pi`, `infinity` |
| Operators | `dot`, `times` (not `cross`), `plus.minus`, `arrow.double` |
| Literal text | `"text here"` |
| Vector / matrix | `vec(x_1, x_2)`, `mat(1, 2; 3, 4)` — `;` separates rows |
| Cases | `cases(1 "if" x > 0, 0 "else")` |
| Multi-line alignment | `$ a &= b \ &= c $` |
| Boxed result | no `\boxed{}`; use `#block(stroke: 0.5pt, inset: 8pt)[$ ... $]` |

In prose, escape a literal slash as `\/` so it is not read as a fraction.

### physica

Pin **0.9.7 or later**. `0.9.5` and `0.9.6` fail on Typst 0.15 with
`unknown symbol modifier` as soon as you touch `braket`/`bra`/`ket`. Existing
files in the user's coursework still pin `0.9.5` — bump them when you touch one.

Verified on 0.9.8:

```typst
$ dv(f, x) $                      // total derivative
$ pdv(f, x), pdv(f, x, y) $       // partial, mixed partial
$ (pdv(U, T))_V $                 // at constant V — parenthesise, then subscript
$ evaluated(pdv(U, T))_(V=0) $    // evaluation bar
$ grad f, div vb(E), curl vb(B) $ // vector calculus, vb() for bold vectors
$ dd(x) $                         // upright differential
$ abs(x), norm(v), order(x^2) $
$ ket(psi), bra(phi), braket(psi, phi), expval(H) $
```

Gotcha: physica's `eval` alias is shadowed by the stdlib `eval` inside math mode.
Use `evaluated(...)` instead.

### Numbers and units

```typst
#import "@preview/unify:0.7.1": num, qty, qtyrange
#qty(9.81, "m/s^2")   #num(1.23e-4)   #qtyrange(80, 300, "K")
```

`unify` exports both `num` and `qty`. `zero:0.5.0` exports `num`, `set-num`,
`ztable` and friends but **not** `qty` — it exists in the package but is not
re-exported from the entrypoint, so importing it fails. Reach for `zero` when you
want siunitx-style table alignment and uncertainty formatting (`#num("385(4)")`),
`unify` when you just want a quantity inline.

### Plots

`lilaq` (0.5.0, verified) for data plots; `cetz` for drawings; `fletcher` for
node-and-arrow diagrams.

```typst
#import "@preview/lilaq:0.5.0" as lq

#figure(
  lq.diagram(
    xlabel: $T slash "K"$, ylabel: $C_V$,
    lq.plot(xs, ys, mark: none, label: [Debye]),
    legend: (position: top + left),
  ),
  caption: [Heat capacity.],
) <fig:cv>
```

Spread multiple series into one diagram:

```typst
lq.diagram(
  ..data.map(d => lq.plot(d.x, d.y, mark: none, label: [#d.name])),
  legend: (position: top + right),
)
```

Diagram options: `title:`, `xlabel:`/`ylabel:`, `xlim: (0, 10)`, `ylim: (0, 1)`,
`width: 100%`, `height: 80%`, `legend: (position: top + right)`.
Mark options: `mark: none`, `stroke: 1.5pt + red`, `label: [text]`.
`lq.bar(centers, heights, width: w, label: [text])` for bar charts.

## Typst math outside `.typ` files

The Obsidian vault at `~/Documents/notes/general-vault/` uses **Typst** notation,
not LaTeX: inline `$...$`, display `$$...$$`, and plots in ` ```lilaq ` fenced
blocks. Everything in the math sections above applies there. The compile loop does
not — there is no compiler in that path, so be correspondingly more careful, and
lean on syntax you have seen work rather than syntax you expect to work.

## Packages

Pin an exact version in every `@preview` import; unpinned imports are not a
thing, and a floating version is how a document that compiled last term stops
compiling.

Before reaching for a package, check what is already local:

```nu
ls ~/.cache/typst/packages/preview/
```

Cached right now: `cetz`, `codetastic`, `elembic`, `fletcher`, `lilaq`, `oxifmt`,
`physica`, `tiptoe`, `unify`, `zero`. Anything else downloads on first compile,
which needs network.

When unsure what a package exports, read its source instead of guessing — the
entrypoint named in `typst.toml` lists the re-exports, and that is authoritative
in a way that recall is not:

```nu
cat ~/.cache/typst/packages/preview/<pkg>/<version>/typst.toml
```

## Reading errors

Typst errors carry a file, a line, a column, and usually a hint — read all four
before changing anything.

- `unresolved import` — the name is not exported from that entrypoint. Read the
  entrypoint (above); do not try a different spelling.
- `unknown variable` in math — a package function you did not import, a stdlib
  name shadowing it, or a multi-letter run Typst read as a variable product.
- `package found, but version X does not exist` — the message names the latest
  available version; use it.
- Content overflowing the page usually wants `width:` on the figure, `columns:`
  weights on the table, or `#set page(flipped: true)` for a wide one.
