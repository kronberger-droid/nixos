---
name: nushell
description: Write and run Nushell for scripting and data munging instead of Python, from the bash-only Bash tool.
when_to_use: >-
  Whenever you are about to reach for Python, jq or awk to parse, reshape or
  summarise data (JSON, YAML, TOML, CSV, lock files, logs, file listings), do
  date or string munging, or write a throwaway script. Also when writing or
  debugging any `.nu` file or `nu -c` one-liner, or when nu prints a parse or
  type error.
---

# Nushell

Martin scripts in Nushell, not Python. The Bash tool runs bash, so every nu
snippet goes through `nu`. Nu moves fast and this machine runs a build of
upstream main (flake input `nushell-src`, no ref), so old tutorials and your
memory are unreliable. When a flag is in doubt, run `nu -n -c 'help <cmd>'`.

Full verified cheatsheet, with the version history and the error table:
`~/.config/nixos/modules/home-manager/apps/skills/nushell-research.md`.
Grep it before guessing.

## Running it

- One-liner: `nu -n -c '<code>'`. Always `-n`: without it nu loads Martin's
  `config.nu`, whose `display_output` hook changes how results print.
- Anything past a line or two: write `$CLAUDE_JOB_DIR/tmp/x.nu` and run
  `nu -n x.nu`. Or feed a heredoc: `nu -n /dev/stdin <<'EOF' ... EOF`.
  Avoid nested quoting in `-c`.
- Quoting in `-c`: bash single quotes outside, nu double quotes inside. A nu
  single-quoted string cannot contain `'`. Use `"..."` or a raw string
  `r#'it's'#`.
- Regexes with backslashes need nu single quotes (`'\w+'`) or a raw string,
  because `"\w"` is a parse error (unrecognized escape). Bash single quotes
  cannot hold those, so any regex with `\` goes in a heredoc or a `.nu` file.
- Pass data in through env vars (`Q=x nu -n -c 'print $env.Q'`), not by
  splicing strings.
- stdin needs a flag: `printf 'a\nb\n' | nu -n --stdin -c 'lines | length'`.
  Without `--stdin` the input is silently empty and `lines | length` is `0`.
- Only the last expression prints. Use `print` for the rest, and finish with
  `to json -r`, `to text` or `str join (char nl)` when the output is for you
  to read. A bare table is box-drawn and wrapped at about 80 columns.
- Script args: `def main [file: path, --count (-c): int = 2, ...rest] {...}`,
  run as `nu x.nu f.txt -c 5`. `--help` comes free.
- Parse-check before running: `nu -n --ide-check 10 x.nu`. Its exit code is
  always 0, so grep the output for `"severity":"Error"`. `nu-check` on a
  relative path fails with `File not found`; use an absolute path.
- Errors go to stderr with a `nu::...` code. `--error-style plain` gives a
  stable layout.

## Traps that bite first

1. **`open` guesses the parser from the extension.** `flake.lock`, `.log`,
   `.ini`, extensionless files come back as a byte stream, and cell paths fail
   with `byte stream doesn't support cell paths`. Write
   `open --raw flake.lock | from json`.
2. **pipefail is on.** A failing external as a statement aborts the whole
   script, silently, with its exit code. Use `| complete`, `try`, `do -i`, or
   `| ignore` when failure is acceptable.
3. **No `&&` or `||`.** Use `;`, `and`, `or`, `try`. Also no heredocs, and
   `else` must sit on the same line as `}`.
4. **Spaces around operators are mandatory.** `$x+1` and `5 -3` fail with
   unhelpful errors. A negative literal as an argument parses as a flag, so
   write `f (-1)`.
5. **`mut` cannot be captured by a closure.** `each {|x| $s += $x}` is a parse
   error. Use `for`, `reduce` or `math sum`.
6. **`each` takes one closure parameter** and drops `null` results. Use
   `enumerate` for an index. `par-each` returns results unordered unless
   `--keep-order`.
7. **Globs in variables do not expand.** `ls $pat` and `^echo $g` take the
   string literally. Use `glob $pat`, `ls ($pat | into glob)`, or
   `^echo ...(glob $g)`.
8. **`str length` counts bytes.** Use `-g` for graphemes.
   `str substring` takes a range with inclusive end: `1..3`, `(-3)..`.
9. **`into datetime` on an int means nanoseconds.** For epoch seconds use
   `--format "%s"` or multiply by `1_000_000_000`. There is no month or year
   duration, and datetimes have no cell paths (use `| into record`).
10. **`parse` on external output needs `| lines` first** (since 0.113).
    Captured values are strings; convert with `into int col`.
11. **Type errors are caught at parse time**, so a `try` around them does not
    help, and nothing in the script runs. Data-dependent errors are runtime.
12. **`from csv` infers types.** `007` becomes `7`. Use `--no-infer` to keep
    text.
13. **Missing keys error.** Use `$r.x?`, `get -o x`, `| default 0`.
    `get -i`, `filter`, `let-env`, `date to-record` and `range` are gone in
    this build. `str upcase`/`str downcase` still work but warn on stderr; use
    `str uppercase`/`str lowercase`.
14. **`http post` with a record needs a content type:**
    `http post --content-type application/json $url {a: 1}`.
15. **`where type == match`** hits the `match` keyword. Quote it:
    `where type == "match"`.

## Idioms

```nu
# read, reshape
open --raw flake.lock | from json | get nodes | transpose name node
open a.json | get deps | where v > 1 | select n v | sort-by v -r
open p.csv | group-by city --to-table | each {|g| {city: $g.city, avg: ($g.items.age | math avg)}}
$t | update age {|r| $r.age + 1}       # column must exist
$t | insert z 1                        # column must NOT exist
$t | upsert z 1                        # either
[[a b]; [1 2]] | to json -r

# write
$d | to json | save -f out.json        # -f overwrites, -a appends
open Cargo.toml | upsert package.version "0.2.0" | save -f Cargo.toml

# strings and regex
"a=1, b=22" | parse -r '(?P<k>\w)=(?P<v>\d+)'
"hello" | str replace -r "l+" "L"      # literal unless -r; -a for all
$s =~ '^foo'                           # substring match unless anchored
$"n=($n), next=($n + 1)"               # interpolation: expressions in ( )

# dates and sizes
"2024-03-05" | into datetime | format date "%F"
(("2024-12-25" | into datetime) - ("2024-01-01" | into datetime)) / 1day | math floor
ls **/* | where type == file | sort-by size -r | first 5 | select name size

# externals
^rg -n foo f.txt --no-heading | lines | parse "{n}:{t}"
let r = (^cmd arg | complete)          # {stdout stderr exit_code}
if $r.exit_code != 0 { error make {msg: $r.stderr} }
^cmd e> /dev/null                      # not 2>/dev/null

# control flow
for i in 1..3 { print $i }
try { 1 / 0 } catch {|e| $e.msg }
def --env setit [] { $env.FOO = "bar" }   # only --env persists env changes
```

## Python to Nushell

| Python | Nushell |
|---|---|
| `json.load` / `d["a"]["b"]` / `d.get("x")` | `open f.json` / `$d.a.b` / `$d.x?` |
| list comprehension with filter | `where` then `get` or `select` |
| `sorted(key=...)` / `Counter` | `sort-by col -r` / `uniq -c` |
| `sum`, `mean` | `math sum`, `math avg`, `math median` |
| `re.search` / `re.sub` / `re.findall` | `=~` / `str replace -ar` / `parse -r` |
| `split`, `join`, `strip` | `split row`, `str join`, `str trim` |
| `strptime` / `strftime` | `into datetime -f` / `format date` |
| `(d2 - d1).days` | `($d2 - $d1) / 1day \| math floor` |
| `os.walk`, `rglob` | `glob **/*.py` (absolute) or `ls **/*.py` |
| `open().read()` / `.readlines()` | `open --raw f` / `open f \| lines` |
| `subprocess.run(capture_output=True)` | `^cmd \| complete` |
| `requests.get(u).json()` | `http get $u` |
| `argparse` | `def main [...]` |
| `try/except`, `raise` | `try/catch`, `error make {msg: "..."}` |
| `hashlib.sha256`, `base64` | `hash sha256`, `encode base64` |
| `sqlite3` | `open x.db \| query db "select ..."` |

## When Python is justified

Say so when you fall back. Nu genuinely cannot do these well:

- Big integers or exact decimals (i64 only, `into int` saturates silently).
- Deep recursion (limit 50, raising it stack-overflows near depth 1000).
- Calendar maths past fixed durations (months, years, business days).
- Dataframes, numpy, linear algebra, plotting.
- Binary protocols, sockets, zip/tar libraries, sessions and retries over HTTP.
- Unicode normalisation, encoding detection, locale collation.
- Editing a file while preserving comments or layout. YAML and JSON
  round-trips lose them. Use the Edit tool for textual edits.

## Before you hand back

Run the script. Nu catches most mistakes at parse time, so a clean
`--ide-check` plus one real run on the actual input is the bar. Report the
output you saw, not the output you expect.
