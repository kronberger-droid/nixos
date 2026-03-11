# Global Instructions

## Shell
- I use **Nushell** (`nu`) as my default shell.
- When suggesting shell commands, write them in Nushell syntax, not Bash/POSIX.

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
