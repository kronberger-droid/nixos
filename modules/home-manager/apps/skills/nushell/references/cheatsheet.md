# Nushell cheatsheet for an LLM agent (verified on the installed `nu`)

Audience: Claude Code writing Nushell instead of Python for scripting and data munging, run from a bash-only tool.
Reference file of the `nushell` skill (`../SKILL.md`), the verified ground truth
for this machine. Where `upstream/*.md` disagrees with it, this file wins.

## 0. What "0.116.2" actually is

- `nu --version` prints `0.116.2`. Binary: `/nix/store/...-nushell-0.116.2/bin/nu`.
- It is **upstream main, not a release**. `flake.nix` input `nushell-src` is `github:nushell/nushell` with no `ref`, locked at rev `e6b30c87a` (2026-11-03, #19417). There is no 0.116.2 blog post and no tag. Latest release post is 0.116.1 (2026-10-04).
- Consequence: the release notes below are necessary but not sufficient. Anything marked **[main]** landed after 0.116.1, is in this binary, and is not in any blog post. Those are cited by PR number (local checkout `~/Projects/rust/nushell`, `git log 0.116.1..HEAD`, 191 commits) and every one was confirmed by running it.
- `debug experimental-options` here: `pipefail`, `reorder-cell-paths`, `enforce-runtime-annotations` are **opt-out (on)**; `dc-glob`, `native-clip`, `cell-path-types` opt-in (off).
- `nu -c` and `nu file.nu` load the user's `config.nu` unless `-n`. This config sets a `display_output` hook (`if (term size).columns >= 100 { table -e } else { table }`) and defines custom `pwd` and `banner`. For reproducible agent runs use `nu -n -c '...'` (no config, std lib kept; verified `use std/assert` works under `-n`).

Primary sources used (all consulted for this file):
- Book: https://www.nushell.sh/book/ , command reference: https://www.nushell.sh/commands/
- Release notes `https://www.nushell.sh/blog/<date>-nushell_v0_<N>_0.html` for 0.100 to 0.116.1 (index https://www.nushell.sh/blog/). Abbreviated below as `blog 0.N`.
- Source: github.com/nushell/nushell, local checkout `~/Projects/rust/nushell`.
- The binary: `help <cmd>`, `help operators`, `scope commands`, `debug experimental-options`, `nu --help`.

Convention: **Verified** means the snippet was run on this binary and the shown result matched. Every snippet in this file is verified unless it sits under a heading that says otherwise. Snippets are shown as the nu code only; wrap in `nu -n -c '...'` from bash.

---

## 1. Invoking from bash

### Quoting

Put nu code in bash single quotes; use nu double quotes inside. Verified:

```sh
nu -n -c 'let x = "a b"; $"x=($x)"'          # x=a b
nu -n -c 'print "say \"hi\""'                # say "hi"
```

- Nu single-quoted strings have **no escape for `'`**. `'it''s'` prints `it''s`. Verified. Use a double-quoted string, or a raw string `r#'it's'#` (verified, also holds embedded `"` and `\n` literally and spans lines).
- `$`, backticks inside bash single quotes reach nu untouched. Nu does not expand `$HOME` inside `"..."`; use `$env.HOME`.
- To avoid all quoting, feed a heredoc to `nu /dev/stdin`. Verified:

```sh
nu /dev/stdin <<'EOF'
let s = "it's"
print $"($s) ok"
[1 2] | each {|x| $x * 2} | to json -r
EOF
```
`nu -` is **not** accepted (`Invalid short flag`). `nu -c "$(cat <<'EOF' ... EOF)"` also works. Or write a `.nu` file and run `nu file.nu`.

- Pass data in via env vars, not string splicing: `Q='a"b' nu -n -c 'print $env.Q'` prints `a"b`. Verified.

### Only the last value prints

In `-c` and in scripts only the final expression is printed (`1; 2` prints `2`). Use `print` for the rest. `print -e` goes to stderr. `nu --no-newline -c '"x"'` omits the trailing newline. Source: `nu --help`.

### Args to `.nu` files and `-c`

```nu
# g.nu
def main [file: path, --count (-c): int = 2, ...rest] { print $"($file) ($count) ($rest)" }
```
`nu g.nu f.txt -c 5 x y` prints `f.txt 5 [x, y]`; `--count=5` works. Verified.

- A script with `def main` runs `main` with the CLI args. Without `main`, top-level statements run and extra args are ignored.
- Subcommands: `def "main foo" [x: int] {...}` then `nu sub.nu foo 2`. Verified.
- `nu m.nu --help` prints generated usage. Missing/mistyped args give `nu::parser::missing_positional` / `parse_mismatch`, exit 1.
- `nu -n -c 'def main [x] { print $x }' extra` also passes `extra` to `main` (verified). Surprise: `-c 'def main [a] {...}'` with no arg dies with `Missing required positional argument`, because `main` is auto-called.
- Script args do not go through `$args`; there is no `sys.argv`.

### stdin: needs `--stdin`

```sh
printf 'a\nb\nc\n' | nu -n --stdin -c 'lines | length'      # 3
printf 'a\nb\nc\n' | nu -n --stdin -c '$in | lines | length' # 3
printf 'a\nb\nc\n' | nu -n -c 'lines | length'              # 0  (silently no input!)
printf 'a\nb\n' | nu -n --stdin script.nu                  # script sees it as $in
```
Without `--stdin`, `-c` and script files get `nothing` as input: `$in | from json` fails with `Pipeline empty`, `lines | length` silently returns 0. With `--stdin` the data is the pipeline input, so a leading `$in |` is optional. In a script file, capture it first: `let d = $in` as the first statement. Source: `nu --help` ("--stdin: redirect standard input to a command (with -c) or a script file"); behaviour verified.

### Exit codes

| Situation | Exit |
|---|---|
| clean | 0 |
| `exit 3` | 3 |
| uncaught nu error (parse or run) | 1, message on **stderr** |
| script statement runs a failing external (see pipefail, section 6) | the external's code, silent |
| `^sh -c "exit 5"` as last statement | 5 |

Verified. Use `--error-style plain` for a stable, ANSI-free, greppable error layout (verified). Fancy errors carry `nu::...` codes you can match.

### Parse-check before running

```sh
nu -n --ide-check 10 file.nu       # JSON lines on stdout, EXIT CODE IS 0 EVEN ON ERRORS
nu -n --ide-check 10 bad.nu        # {"type":"diagnostic","severity":"Error","message":"Missing argument to `=`.",...}
nu -n -c 'open --raw bad.nu | nu-check --debug'    # prints Error, exit 1
nu -n -c 'open --raw e.nu | nu-check'              # true
nu -n -c 'nu-check --debug /abs/path/e.nu'         # true
```
- `--ide-check` exits 0 regardless; grep the output for `"severity":"Error"`. Verified.
- **`nu-check relative.nu` fails with `File not found`** even though the file exists in cwd. `nu_check.rs` resolves a relative path against `$env.FILE_PWD` / `NU_LIB_DIRS` (source: `crates/nu-command/src/system/nu_check.rs`, `find_in_dirs_env`), and `-c` has no `FILE_PWD`. Use an absolute path, `("f.nu" | path expand)` in parentheses, or `open --raw f | nu-check --debug`. Verified all three.
- `nu-check` only parses; it does not catch runtime errors. Unknown commands are treated as externals at parse time, so `"foo-typo-cmd 1" | nu-check` returns `true`.
- **Trap:** `ls | get name | each {|f| nu-check $f}` returns `true` for every file including broken ones. The item is also the closure's pipeline input, and `nu-check` with string input parses *that input as source* (the bare word `bad.nu`). Verified (`"let x =" | nu-check /abs/e.nu` gives `false`: the piped text wins over the path). Do not loop `nu-check` that way; use `--ide-check` per file.

### Other flags worth knowing (`nu --help`)

`-n/--no-config-file`, `--no-std-lib`, `-I/--include-path` (sets `NU_LIB_DIRS`), `--error-style plain`, `-m/--table-mode`, `--stdin`, `--no-newline`, `--experimental-options '[name=bool]'` (env var `NU_EXPERIMENTAL_OPTIONS`, ignored when running scripts per blog 0.105).

---

## 2. Reading and writing data

### `open` format detection

`open` picks a parser from the extension via a `from <ext>` command in scope. Verified with `open X | describe`:

| File | Result |
|---|---|
| `.json` `.yaml` `.yml` `.toml` `.csv` `.tsv` `.nuon` `.xml` | parsed (record/table) |
| `.md` | parsed AST table (columns `element content content_span`). **Changed in 0.112.1** (#17937). Old string: `open --raw` |
| `.env`, `prod.env` | parsed with `from dotenv` (record of strings), per `help open` |
| `.lock` (flake.lock), `.log`, `.txt`, `.nu`, `.ini`, no extension, `.bin` | **byte stream**. `.ini` is not parsed: `from ini` is a plugin command and plugins are not installed |
| directory | `nu::shell::io::is_a_directory` |

- `from` commands available in this build: `csv dotenv json kdl md msgpack msgpackz nuon ods ssv toml tsv url xlsx xml yaml yml`. Not present: `ini`, `eml`, `ics`, `vcf`, `html`. Source: `scope commands | where name =~ "^from "`.
- Text files opened without a parser are a *byte stream* that prints like text. Cell paths fail on it:

```
open flake.lock | get version
Error: nu::shell::incompatible_path_access
  x Data cannot be accessed with a cell path
  `-- byte stream doesn't support cell paths
```
Fix: `open flake.lock | from json | get version` (verified, `3`). Same for `open --raw f | from json`.
- `open --raw` on UTF-8 text gives a `string`, on non-UTF-8 `binary`. Verified (`open --raw lines.txt | collect | describe` is `string`).
- `open a.json | metadata` has `source` only; `open --raw a.json | metadata` adds `content_type: application/json`. Changed in 0.101 (blog 0.101 #14602: `from` commands drop `content_type`).
- `open *.json` globs and returns a combined result. `open $var` where `$var` holds `"*.json"` does not glob (see section 7).

### Parsing and generating formats

```nu
open a.json | get deps.0.n                          # a
"a,b\n1,2" | from csv                               # table; types are INFERRED
"id\n007\n12" | from csv | to nuon                  # [[id]; [7], [12]]   leading zeros lost
"id\n007\n12" | from csv --no-infer | to nuon       # [[id]; ["007"], ["12"]]
"1,2\n3,4" | from csv --noheaders                   # columns column0 column1
"a;b\n1;2" | from csv --separator ";"
open t.txt | from ssv --minimum-spaces 1            # ssv default needs 2+ spaces between columns
open t.txt | detect columns                         # splits on whitespace, first row = header
"{\"a\":1}\n{\"a\":2}" | from json --objects        # NDJSON; plain `from json` errors on it
[[a b]; [1 2]] | to json --raw                      # [{"a":1,"b":2}]   (default is pretty, indent 2)
{a: 1} | to json -i 2
[[a b]; [1 2]] | to csv                              # quotes cells with , or " correctly
{a: [1 2]} | to yaml --list-indent indented         # a:\n  - 1\n  - 2
{a: 1} | to toml
[[a b]; [1 2]] | to md --pretty
```
- `to json` serialises filesize as bytes int, duration as nanoseconds int, datetime as RFC 3339 string. `{a: 1kb, b: 2day, c: 2024-01-01} | to json -r` gives `{"a":1000,"b":172800000000000,"c":"2024-01-01T00:00:00+00:00"}`.
- `1e10` literals parse as float; an int literal beyond i64 is a **parse error** ("number too large (add `.0` for a float)").
- `to yaml --list-indent compact|indented` replaced `--compact-list-indent` in 0.116 (blog 0.116).
- `from yaml` is **YAML 1.2 since 0.115** (blog 0.115, #18487): `a: yes` gives the string `yes`; old behaviour `from yaml --spec 1.1` gives `true`. Verified both. Multi-document `---` input yields a list of records.
- `from xml` gives `{tag, attributes, content}` trees. Text nodes have `tag: null`. Verified.
- `from json` strips one leading BOM **[main]** (#19383).

### `save`

```nu
{a: 1} | to json | save -f out.json      # -f / --force overwrites. Without it: "Destination file already exists"
"x" | save -a log.txt                    # append. Note: no newline added
[[a b]; [1 2]] | save -f o.csv           # format chosen from EXTENSION: .json .csv .yaml ...
{a: 1} | save -f o.weird                 # ERROR: unsupported_input, no `to` converter for the extension
"text" | save -f o.json                  # strings/bytes are written as-is, no conversion
"text" | save -f sub/dir/o.txt           # creates parent dirs (0.116: --force creates missing parents)
^echo hi | save -f e.txt                 # byte streams stream to disk
```
- `[1 2] | save out.json` writes pretty JSON `[\n  1,\n  2\n]`. `ls | save o.json` works.
- `save` is not an in-place edit helper: `open h.txt | str replace x y | save -f h.txt` works because `open` is fully read before write for small files, but do not rely on it for large streams; write to a temp name and `mv`.
- stdout redirection forms: `cmd o> file`, `e> file`, `o+e> file`, `e>| next`, `o+e>| next`. Not `2>/dev/null` (that is passed to the command as an argument and does nothing). Verified: `^sh -c "echo err >&2" e> /dev/null` is silent.

### HTTP

```nu
http get http://127.0.0.1:8765/a.json | get name       # JSON auto-parsed by Content-Type
http get :8765/a.json                                   # ":port" means http://localhost:port  (0.105)
http get --raw URL                                      # byte stream, no parsing
http get --full URL | get status                        # record: urls headers body status
http get --allow-errors --full URL | get status         # 404 -> 404 instead of an error
http get -H [Accept application/json] URL
http get --max-time 2sec URL                            # duration, not int (0.100, blog 0.100 #14237)
http post --content-type application/json URL {a: 1}   # record body auto-serialised (pretty JSON)
http post URL "raw text"                                # string/binary body
{a: 1} | to json | http post --content-type application/json URL
```
- A bare record body **without** `--content-type` fails: `Type mismatch. Accepted types: [binary, string]`. `-t json` with a record also type-mismatched in my run; do not use it. Use `--content-type application/json` (verified: server received `{"a": 1}` pretty-printed and `Content-Type: application/json; charset=utf-8`).
- Non-2xx raises `nu::shell::http_error` ("HTTP Error 404 (Not Found)"). `http` commands respect `HTTP_PROXY`/`NO_PROXY` (blog 0.113, 0.112.1).
- Tested against a local `python -I -m http.server` and a 15-line echo server; the public internet was also reachable (`http get https://example.com` returned 577 chars).

### Listing and finding files

```nu
ls | where type == file | get name
ls **/*.json | get name                 # glob built in; relative names
ls -l p.csv | get 0 | select name size type
ls | sort-by size -r | first 2 | get name
ls | where modified < (date now) - 7day
ls **/* | where type == file | get size | math sum     # filesize value, e.g. 12.8 kB
glob **/*.json                          # absolute paths, list<string>
glob *.{json,csv}                       # brace expansion
glob **/*.{json,csv} --exclude [**/out*] --depth 3 --no-dir
```
- `ls` output is **sorted by name** since 0.101 (blog 0.101). Hidden files need `ls -a`. `ls` of a missing pattern errors: `No matches found for Expand("*.nothing")`.
- A pattern held in a variable or quoted string is **not expanded**: `let pat = "*.json"; ls $pat` errors `No matches found for DoNotExpand("*.json")`. Use `ls ($pat | into glob)` (verified, 4 hits) or `glob $pat`.
- `mv`/`cp`/`du` globs no longer match dotfiles without `-a` (blog 0.110). `rm` is **permanent** by default here (`rm -t` for trash; `help rm`). `rm -v`, `mkdir -v`, `mv -v` return tables (blog 0.113).
- Path helpers (input is the path, not an argument): `"/a/b/c.tar.gz" | path parse` (stem `c.tar`, extension `gz`), `path basename`, `path dirname`, `path join`, `path exists` (as `"/tmp" | path exists`), `path expand`, `path relative-to`. `path exists /nope` as an argument errors `extra_positional`.
- Temp: `mktemp -d`, `mktemp --suffix .json` (creates in the temp dir since 0.111).

### `find` and `rg`

```nu
ls | find csv | get name                 # find on table matches any column, returns rows
"foo bar" | find foo --no-highlight      # find on a string emits ANSI highlight codes ALWAYS, even piped
open h.txt | lines | find world           # find on list<string>
ls | find -r "^p" | get name             # -r regex
rg -n hello h.txt                        # rg is an external; ^ optional
^rg -n "o" h.txt --no-heading | lines | parse "{n}:{t}"
rg --json hello h.txt | lines | each {from json} | where type == "match" | get data.lines.text
```
- Quote `"match"`: `where type == match` parses `match` as the keyword and errors `Usage: match <value> <match_block>`.
- `find` is **case-sensitive by default since 0.107** (blog 0.107; `--ignore-case` / `-i` to relax). `find` on a string/table adds ANSI color; use `--no-highlight` (flag exists since 0.102) or avoid `find` for programmatic work and use `where name =~ ...` / `str contains`.
- `find` does not accept a plain string as input with `-r` and then `length` (type mismatch); use `=~` for booleans.

---

## 3. Tables, records, lists

Test table used below: `let t = [[name age city]; [ann 31 Wien] [bob 25 Graz] [cy 40 Wien]]`. All verified.

### Types in one minute

- list of records = table. `{a: 1}` record. `[1 2]` list. Index is `0`-based. `describe` shows the type.
- Separators: whitespace or `,` in lists/records. **`;` is an error** in lists and records (`[1 2 3;]`, `{a: 1; b: 2}`), and a header-only table `[[a b];]` is a parse error since 0.116 (blog 0.116).
- `$t.name` (column as list), `$t.1.name`, `$t | get 1.name`, `$t | get name` all work. `get` on a missing column errors `nu::shell::column_not_found`.

### Cell paths and optional access

```nu
{a: {b: 1}} | get a.b            # 1
{a: {b: 1}} | get a.c            # ERROR column_not_found (help: try 'c?')
{a: {b: 1}} | get a.c?           # null
{a: {b: 1}}.a.c? | default 0     # 0
[{a:1} {b:2}] | get a            # ERROR: column missing in one row
[{a:1} {b:2}] | get a? | to nuon # [1, null]
[{a:1} {b:2}] | get -o a         # same, --optional / -o
[{a:1} {b:2}] | select a?        # [[a]; [1], [null]]
[1 2 3] | get 5?                 # null;   [1 2 3].5 errors access_beyond_end
{"a.b": 1} | get "a.b"           # quoted literal key with a dot
let k = "c"; {c: 2} | get $k     # variable key is fine
{a: 1} | reject b?               # no error
{a: 1} | update b? 2             # no-op, no error (0.107)
```
- Cell paths are **case-sensitive since 0.105** (blog 0.105); `!` makes one member case-insensitive: `a.B!.c`.
- `get --ignore-errors/-i` was renamed `--optional/-o` in 0.106 (blog 0.106) and the old flag is **removed in this build [main]** (#19382): `{a:1} | get -i a` gives `doesn't have flag -i`. `get --sensitive/-s` also removed; `filter` removed.
- `null | get a` errors (`nothing doesn't support cell paths`); `null | get a?` returns null.
- `$env.NOPE` errors `column_not_found`; use `$env.NOPE?` and `default`.
- `datetime`, `nothing`, byte streams have no cell paths: `(date now).year` fails. Use `| into record | get year`.
- `[1 2 3] | each {|x| ...}` closure params: **one** parameter only. `each {|x, i|}` is a parse error ("expected 1 closure parameter"); use `enumerate` (`{index, item}`).

### Row/column operations

```nu
$t | where age > 28 and city == Wien
$t | where {|r| $r.age > 28}
$t | where name =~ '^a'
$t | where age in [25 31]
$t | select name age
$t | reject city
$t | update age {|r| $r.age + 1}            # column must exist
$t | insert senior {|r| $r.age > 30}        # column must NOT exist ("Column already exists")
$t | upsert zip 1010                        # either
$t | rename n a                             # positional rename of leading columns
$t | rename -c {name: n}                    # by name
$t | move age --before name
$t | sort-by age                            # also: sort-by city age --reverse, sort-by -r age
$t | uniq-by city                           # first of each; --keep-last (0.111)
$t | get city | uniq -c                     # value, count
$t | first 2 ; $t | last 1 ; $t | skip 1 ; $t | drop 1 ; $t | take 1
$t | enumerate | where index > 0 | get item.name
$t | any {|r| $r.age > 39}                  # all {...} too
$t | length                                  # count rows. (records: use `columns | length`)
$t | append {name: dan age: 5 city: x}
$t | join ($t | select name age | rename n a) name n    # inner join on columns
```
- `where` accepts a field expression (`age > 28`), a closure (`{|r| ...}`), or a closure stored in a variable (`where $c`, 0.105). The legacy `where $it > 2` still parses in this build; prefer `$in`/closures. `$it` is reserved (0.111) then re-allowed for `let it` in 0.112.1.
- **`where` with a variable column name does not work**: `let col = "v"; ... | where $col > 2` is a type error. Use `where {|r| ($r | get $col) > 2}`.
- `each` **drops nulls**: `[a b] | each {|x| if $x == "a" { $x }}` gives `[a]`. `each --keep-empty` keeps `null`. `null | each {...}` returns null without calling (0.107).
- `par-each` returns results **unordered** (`[4, 2, 6]` observed; unordered streaming since 0.112.1). Add `--keep-order`/`-k` when order matters. `--threads N` exists.
- `reduce` closure is `{|it, acc| ...}` (item first, accumulator second). `reduce --fold 100 {...}` (`-f`). `[1 2 3] | reduce {|it, acc| $acc - $it}` is `-4`.
- `each {|x| ... continue ...}` is a **compile error** (`nu::compile::not_in_a_loop`, since 0.108, blog 0.108); `return` in a closure returns from the closure.
- Equality: `1 == 1.0` is true, `"1" == 1` is false, `null == null` true.

### Group, pivot, aggregate

```nu
$t | group-by city                                  # RECORD: {Wien: <table>, Graz: <table>}
$t | group-by city --to-table                       # table [city items]
$t | group-by city --to-table | each {|g| {city: $g.city, avg: ($g.items.age | math avg)}}
$t | group-by city | transpose city rows | insert n {|r| $r.rows | length}
$t.age | math sum ; $t.age | math avg ; $t.age | math max ; $t.age | math median ; $t.age | math stddev
```
- `group-by` takes several keys and nests records since 0.101 (blog 0.101); `null` keys are dropped from record output in 0.115 (#18709), kept by `--to-table`.
- `transpose` semantics: `$t | transpose` -> columns `column0..`; `transpose key val` names the first two columns only; `transpose -r -d` makes a record from a 2-column table or a list of records (`[{k: a v: 1} {k: b v: 2}] | transpose -r -d` gives `{a: 1, b: 2}`); `transpose` rejects stream of non-records (0.103). `-i` ignores the header row.
- Build a record from pairs: `[[a 1] [b 2]] | into record`; `reduce -f {} {|it, acc| $acc | merge {($it.k): $it.v}}`.
- Record ops: `columns`, `values`, `items {|k v| ...}` (returns a list), `merge {c: 3}`, `merge deep`, `reject`, `select`, `transpose k v`. `merge` needs same kind on both sides: `table | merge {record}` is a type error.
- `flatten`: list of lists -> flat list; table with a list column -> one row per element (`[[a b]; [1 [2 3]]] | flatten` gives rows `(1,2)`,`(1,3)`); record column -> merged columns, and **since 0.114/0.116 a colliding inner column is renamed `<parent>_<field>`** instead of overwriting (blog 0.114 #18407, blog 0.116).
- `zip`: `$t.name | zip $t.age` gives pair lists; `| into record` makes a record.
- Lists: `append`, `prepend`, `++` (list/string/binary only; `[1] ++ 4` is `operator_unsupported_type`), `window 2`, `chunks 2`, `skip while`, `take while`, `each while`, `reverse`, `sort`, `sort -r`, `sort -i` (case-insensitive), `sort --natural` (`a2` < `a10`), `uniq`, `range`: `1..5`, `1..<5`. `generate {|x| if $x < 4 {{out: $x, next: ($x + 1)}}} 0` gives `[0 1 2 3]`.
- `first`/`last` on an empty list return `null`, not an error (0.109, blog 0.109); `first --strict` errors `access_empty_content`.
- Sorting: `sort` works on mixed numbers (`[1 2.5]`), strings sort lexicographically unless `--natural`. `sort-by b` where `b` is missing does **not** error.
- Streams: `ls`, `1..3 | each`, `open | lines` are lazy streams; `describe` prints `(stream)`. `collect` forces.

### Numbers

- `/` always returns float (`10 / 4 = 2.5`; `10 / 5 = 2.0`), `//` floor division, `mod` is floor-based (0.100 breaking, blog 0.100), `**` right-associative (0.108).
- Int overflow **errors** (`nu::shell::operator_overflow`) for `+ * **`. Float formatting keeps `.0` (0.106). `0.1 + 0.2 = 0.30000000000000004`.
- Literals: `1_000`, `0xff`, `0b11`, `1e3` (float), `1kb` (1000 bytes), `1kib`, `5min`, `2day`.

---

## 4. Strings and regex

All verified.

```nu
"Hello" | str uppercase ; str lowercase ; str capitalize ; str title-case ; str snake-case ; str kebab-case ; str camel-case
"  pad " | str trim            # --left / --right ; str trim --char x
"hello" | str contains "ell"   # -i case-insensitive
"hello" | str starts-with "he" ; str ends-with "lo" ; str index-of "l"      # 2
"hello" | str replace "l" "L"       # first match, LITERAL by default
"hello" | str replace -a "l" "L"    # all, literal       heLLo
"hello" | str replace -r "l+" "L"   # regex               heLo
"hello world" | str replace -r '(\w+) (\w+)' '$2 $1'    # world hello   (capture refs $1 $2)
"hello" | str reverse ; str length ; str distance "Hallo"
"abc def" | str stats
"ab" | fill -w 5 -a r -c "*"        # ***ab   (padding; also -a left/center)
[a b] | str join ","                # a,b
"x" + "y" ; "a" ++ "b"              # both concatenate; `"a" * 3` is an error
```
- **`str length` counts UTF-8 bytes**: `"héllo" | str length` is `6`. Use `str length --grapheme-clusters` (or `-g`) for 5. (`--chars` also exists.) `--bytes` flag does not exist.
- **`str substring` takes a range, inclusive end**: `"hello" | str substring 1..3` is `ell`; `1..<3` is `el`; `..2` is `hel`; `2..` is `llo`; negative start needs parentheses: `(-3)..` is `llo`; `-3..` is parsed as a flag. The old `str substring 1 3` / `1,3` form errors `Can't convert to range` (range form since the 0.8x era; range handling fixed in 0.102, #14863). Byte indices; `-g` for graphemes. Since 0.107 it no longer keeps `content_type` metadata (blog 0.107).
- `str upcase` / `str downcase` still run but print a deprecation warning on stderr (deprecated 0.114.0, blog 0.114 #18364; removal planned). Use `str uppercase` / `str lowercase`. The warning is noisy in agent logs and also appears on `2>&1`.
- `str escape-regex` exists. `str expand` expands `{a,b}` braces.
- `split row "-"` (string sep), `split row -r '\d+'` (regex), `split column ":" k v` (table), `split chars`, `split words`, `lines`. **`split column` without names uses `column0`, `column1`** (verified; the 0.107 post text claims `column1` default but its example shows otherwise; trust the run). Duplicate column names are rejected **[main]** (#19362).
- `lines` replaces invalid UTF-8 by default; `lines --strict` fails (0.114, #18261); `lines --skip-empty`.

### Regex

- Operators: `=~` / `like` (match), `!~` (no match). Regex engine is `fancy_regex` (0.102), so look-around and backreferences work: `"foobar" | parse -r 'foo(?=bar)(?<x>bar)'`, `"aaa" =~ '(a)\1'`, `"foobar" =~ '(?<!x)bar'` all verified. Case-insensitive via inline flag `(?i)`: `"ABC" =~ "(?i)abc"` is true.
- `=~` is substring-style unless anchored: `"abc" =~ "b"` true, `"abc" =~ "^b"` false.
- `parse` has two modes:
  ```nu
  "x=1" | parse "{k}={v}"                                  # simple pattern -> columns k, v (strings)
  "x=1, y=22" | parse -r '(?P<k>\w)=(?P<v>\d+)'             # regex with named groups -> columns k v
  "x=1" | parse -r '(\w)=(\d)'                              # unnamed -> capture0 capture1
  ["a=1" "b=2"] | parse "{k}={v}"                           # works per element on a list
  "2024-01-02" | parse "{y}-{m}-{d}" | into int y m d
  ```
  Captured values are **strings** (convert with `into int col`). Unmatched optional groups give `null` (0.106, #16094); `_` placeholder ignores a field (0.105).
- **`parse` does not split streamed text into lines since 0.113.** `^printf "a=1\nb=2\n" | parse "{k}={v}"` yields one row `a | 1\nb=2`. Always `| lines | parse ...`. Verified both ways.
- Literal braces in `parse`/`format pattern` patterns: an unescaped `{` without `}` is an error since 0.116.
- Regex special chars in `str replace` without `-r` are literal: `"a.b" | str replace "." "-"` gives `a-b` (only first dot; `-a` for all).
- Escapes: in `"..."` use `\n \t \" \\ \u{1F600} \x41`; in `'...'` and `r#'...'#` nothing is escaped (`help escapes`).

### Interpolation

```nu
let n = 3; $"n=($n), next=($n + 1)"        # n=3, next=4
let r = {a: 1}; $"v: ($r.a)"                # v: 1
$"list: ([1 2] | str join ',')"             # expressions go in ( )
$"literal \(paren\)"                        # escape parens
$'single ($n)'                              # $'...' also interpolates, no escapes
$"$s!"                                      # NOT interpolation: prints $s!
"($s)"                                      # plain string: prints ($s)
```
- A list interpolates as `[1, 2]`, a record as a nested rendering; convert explicitly with `to json -r`/`str join`.
- Variables are not interpolated in plain `"..."`.

---

## 5. Dates, durations, filesizes, conversions

All verified. Local timezone of the test box is +01:00 and `LANG` is German, which shows up below.

### Datetime

```nu
"2024-03-05" | into datetime                     # local midnight. A date/time without offset is LOCAL time
"2024-03-05T10:20:30+02:00" | into datetime
"2024-03-05 10:20:30" | into datetime
"05/03/2024" | into datetime --format "%d/%m/%Y" # -f is the short flag; still valid. `--list` shows %-codes
"2024-03-05T10:00:00Z" | into datetime | date to-timezone "Europe/Vienna"
date now | format date "%Y-%m-%d"                 # chrono strftime codes; %F %T %s %+ %j %Z work
"2024-03-05T10:20:30Z" | into datetime | format date "%s"          # 1709634030 (epoch seconds as string)
date now | format date "%s" | into int            # epoch seconds
date now | into int                               # NANOSECONDS since epoch
1700000000 | into datetime                        # WRONG: int means NANOSECONDS -> 1970-01-01 00:00:01
1700000000 | into datetime --format "%s"          # 2023-11-14 22:13:20 UTC  (seconds)
1700000000 | $in * 1_000_000_000 | into datetime  # also seconds
2024-03-10                                         # bare datetime literal (UTC midnight); 2024-03-10T10:00:00Z too
```
- `into datetime` of an **int is nanoseconds** (`help into datetime`: "An int, or a string of digits, is nanoseconds since 1970-01-01 UTC").
- Human strings: `"tomorrow" | into datetime` works in this build. History: removed in 0.104 (blog 0.104, use `date from-human`); restored by the jiff-based reader **[main]** #19398. `date from-human` still exists. For portable scripts use ISO strings or `--format`.
- `into datetime --formats` lists the formats read without `--format` **[main]** #19413.
- `format date` uses the locale: `"2024-03-05" | into datetime | format date "%A %B"` printed `Dienstag März` here (blog 0.107: respects `$env.LANG`, `LC_ALL` overrides). Run with `LC_ALL=C` for English names, or avoid names.
- `into datetime --timezone utc` yields `+0000` offsets (0.112.1 #17855).
- `describe` reports `datetime` (was `date` before 0.104).
- **Datetimes have no cell paths.** `($dt).year` fails (`datetime doesn't support cell paths`). Use `$dt | into record | get year` (record: year month day hour minute second millisecond microsecond nanosecond timezone). `date to-record` / `date to-table` are gone (deprecated 0.101, removed 0.102, blog 0.101/0.102).
- Rebuilding from parts: `{year: 2024 month: 3 day: 5} | into datetime` works (local midnight). Month overflow (`Jan 31` + month 1 -> Feb 31) errors `nu::shell::incorrect_value`. There is **no month or year duration**: `1month` is not a literal (parsed as an external command) and `+ 1month` fails.
- Operators on datetimes: `-` gives duration, `+`/`-` with a duration gives datetime, comparison works (`ls | where modified > (date now) - 1day`). `older-than` / `newer-than` operators **[main]** #19397.
- `date humanize`: `ls | get modified.0 | date humanize` gives `2 minutes ago`. `date list-timezone`, `date now | date to-timezone utc`.
- Ranges of dates: `seq date --begin-date 2024-01-01 --end-date 2024-01-03` (or `--days 3`) gives strings `["2024-01-01", ...]`.

### Durations and filesizes

```nu
1hr + 30min                          # 1hr 30min
90min | format duration hr           # 1.50 hr         (unit is a string argument; case-sensitive)
(90min) / 1hr                        # 1.5   duration / duration = float
90min | into int                     # 5400000000000 (nanoseconds)
3600sec | into duration              # 1hr
5 | into duration --unit sec         # 5sec
"1:30:00" | into duration            # 1hr 30min      (clock strings: 0.112.1)
"1hr 30min" | into duration
2day > 1hr                           # true
(("2024-12-25" | into datetime) - ("2024-01-01" | into datetime)) / 1day | math floor   # 359
```
Units: `ns us ms sec min hr day wk`. `format duration day` gives `359 day`.

```nu
1gb | into int                       # 1000000000   (gb = 10^9; gib = 2^30)
1kb + 1kib                           # 2.0 kB
1234567 | into filesize              # 1.2 MB
"1.5 MiB" | into filesize | into int # 1572864
1234567b | format filesize kB        # 1234.56 kB
1gb | format filesize mb             # ERROR invalid_unit: units are CASE-SENSITIVE: B kB MB GB TB PB EB KiB ... (blog 0.102)
ls p.csv | get size.0 | into int     # 49
ls **/* | where type == file | get size | math sum        # filesize arithmetic keeps units
```
Display unit/precision come from `$env.config.filesize` (`unit`, `precision`; blog 0.102, `format filesize` decimals follow `float_precision` since 0.111).

### Numbers and strings

```nu
"3" | into int                       # 3
"3.7" | into int                     # 3   (truncates)
3.7 | into int                       # 3
"0x1f" | into int                    # 31 ;  "1f" | into int --radix 16
"abc" | into int                     # ERROR nu::shell::cant_convert  "string "abc" does not represent a valid integer"
try { "abc" | into int } catch { 0 } # 0.  `| default 0` does NOT help: the error is raised first
"9223372036854775808" | into int     # 9223372036854775807  SILENTLY saturates
"true" | into bool ; 1 | into bool
255 | into string ; 255 | into string --decimals 2 # "255.00"
3.14159 | math round --precision 2   # 3.14
{a: 1} | into string                 # ERROR can't convert record to string (use to nuon / to json)
null | into string                   # ERROR parse-time: command doesn't support nothing input
"1,000" | str replace "," "" | into int
[[y]; ["1"]] | into int y            # converts a column
[[y]; ["1"]] | update y {into int}
```
- `into string` no longer modifies strings (0.103).
- `format number` returns a record of renderings (`debug display binary lowerexp upperexp lowerhex upperhex octal`), not a formatted string. For zero-padding use `fill`, e.g. `7 | into string | fill -w 3 -a r -c '0'`.

---

## 6. Control flow, closures, definitions, env, errors, externals

### Basics

```nu
if $a == 1 { "one" } else if $a == 2 { "two" } else { "many" }    # `else` must be on the SAME line as `}`
let x = if false { 1 }                                            # x is null when there is no else
match 2 { 1 => "one", 2 => "two", _ => "other" }
match {a: 1} { {a: $v} => $v }              # destructuring
match [1 2] { [$a, $b] => ($a + $b) }
match "x" { "x" | "y" => "xy", _ => "no" }  # alternatives with |
for i in 1..3 { print $i }
mut i = 0; while $i < 3 { $i += 1 }
mut i = 0; loop { $i += 1; if $i > 4 { break } }
const C = 5                                  # parse-time constant; usable by `source $C`, `use`
let x = 1; let x = $x + 1                    # shadowing is fine; `let` is otherwise immutable
mut r = {a: 1}; $r.b = 2                     # nested assignment on mut works: $t.0.a = 9, $l.0 = 9, $l ++= [2]
```
- `&&` and `||` are **rejected** (`nu::parser::shell_andand`, "use ';' or 'and'"; `shell_oror`, "use 'try' or 'or'"). Boolean ops are `and or not xor`. Chain commands with `;`.
- `if ... \n else {...}` (else on a new line) fails: `Command else not found`. Keep `} else {` on one line.
- A newline ends a statement; a line starting with `|` continues the previous pipeline (verified: multiline `[1 2 3]\n| each {...}\n| to nuon` works). Wrap in `( ... )` to be safe when mixing.
- `let` with type: `let x: int = "s"` is a parse error `expected int, found string`.
- Values equal across statements: only the last statement's value is returned/printed.
- `match` does **not** run a closure returned from an arm since 0.103 (blog 0.103).

### `mut` and closures

```nu
mut s = 0; [1 2 3] | each {|x| $s += $x }
# Error: nu::parser::expected_keyword   x Capture of mutable variable.
```
Closures (`each`, `do`, `where`, `par-each`...) cannot capture `mut`. Rewrite as `for` (which is not a closure and can mutate: `mut c = 0; for x in [1 2 3] { $c += $x }; $c` is `6`), or `reduce`, or `[1 2 3] | math sum`. The same parse error occurs for `do { $c += 1 }`.
`let` variables are captured by value: `let n = 5; let f = {|x| $x + $n}; do $f 1` is `6`.
`break`/`continue` outside a `for/while/loop` (including inside `each`) are compile errors `nu::compile::not_in_a_loop` (0.108).

### Custom commands

```nu
def add [a: int, b: int = 10] { $a + $b }
def f [--verbose (-v), --n: int = 3, ...rest: string] { {v: $verbose, n: $n, rest: $rest} }   # f -v --n 5 a b
def g [x?: int] { $x | default 0 }                 # optional positional; `$x` is `int | nothing`
def len []: string -> int { str length }            # in/out signature; "abc" | len
def "my cmd" [] { "ok" }                            # space in name
def --env setit [] { $env.FOO = "bar" }             # only --env persists env changes to the caller
def h [] { return 5; 6 }                            # return exits the command
def chk [x] { $x }; chk (-1)                       # a bare -1 is parsed as a FLAG: `chk -1` => "doesn't have flag -1"
```
- Without `--env`, `$env.X = ...` inside a `def` is lost; reading `$env.FOO` afterwards errors `column_not_found`.
- Switch flags are `bool` typed (0.111). Signature syntax errors are parse-time since 0.101. A `def` named like a keyword (`def def`) is an error (0.115).
- `def main` special: see section 1. `export def` / `use mod.nu` / `source file.nu`: `source` and `use` need **constant** paths. `let p = "a.nu"; source $p` errors `nu::shell::not_a_constant`; `const p = "lib.nu"; source $p` works. `use` does not implicitly import submodules since 0.114 (blog 0.114).
- Flags before values: `--n 5` or `--n=5`. Repeated flag: last wins (0.106). `--` ends option parsing (0.114).
- Positional `path`-typed params are not made absolute since 0.106 (`..`/`~` still expanded).
- Parameter and `let` annotations are enforced: `def f [x: string] {$x}; let v = 1; f $v` is a parse-time `nu::parser::type_mismatch` (`expected string, found int`). `enforce-runtime-annotations` (on since 0.114) adds run-time `cant_convert` checks for values whose type is only known at run time.

### Environment

```nu
$env.FOO = "bar"; $env.FOO
$env.FOO? | default "unset"
$env.HOME ; $env.PWD ; $env.PATH      # PATH is a list<string>
with-env {FOO: "x"} { ^sh -c 'echo $FOO' }       # scoped; passes to externals
FOO=x ^sh -c 'echo $FOO'                          # inline env prefix works
load-env {AA: 1, BB: 2}
cd /tmp; pwd                                      # cd persists to following statements in the same script
do { cd /tmp; pwd }; pwd                          # cd inside a block/closure is scoped
$nu.home-dir ; $nu.temp-dir ; $nu.current-exe     # renamed from home-path / temp-path in 0.110
$nu.os-info.name                                   # linux
```
Env var names are case-insensitive lookups since 0.111. Nu does not export `$env` changes to the parent bash; nothing you set persists after `nu` exits.

### try / catch / finally / error make

```nu
try { 1 / 0 } catch {|e| $e.msg }                  # "Division by zero."
try { ^false } catch {|e| $e.exit_code }           # 1;  $e.msg = "External command had a non-zero exit code"
try { error make {msg: "a"} } catch { "caught" } finally { print "fin" }   # prints fin, then caught
try { error make {msg: "x"} }; "after"              # error swallowed, "after" runs (try yields nothing)
```
- The catch record has columns **`msg debug raw rendered details`** (verified). The old `json` field was removed in 0.114 (blog 0.114 #18479); use `details`/`rendered`. `finally` doesn't suppress the error message and its return value is unused (0.113); `$in` is defined inside `finally` (0.116).
- `error make`:
  ```nu
  error make {msg: "boom"}
  error make {msg: "bad", help: "try x", code: "my::code", url: "https://example.com"}
  error make {msg: "bad", labels: [{text: "here", span: (metadata "abc").span}]}   # multiple labels
  def chk [x] { error make {msg: "neg" label: {text: "val" span: (metadata $x).span}} }  # single label
  error make --unspanned {msg: "plain"}               # no source snippet
  ```
  `label` takes one label, `labels` a list (0.110, blog 0.110). A label needs a `span` record `{start end}` (usually from `metadata`). Uncaught, `error make` prints `Error: nu::shell::error` (or your `code`) and exits 1.
- `do -i { cmd }` (`--ignore-errors`) swallows errors from a block (returns nothing); `do -c` is `--capture-errors`. Old `do -s/-p` removed (0.104).
- Runtime vs parse-time: type errors on literals/known types (`"1" + 1`, `let x: int = "s"`, `{a:1} | length`) are caught at **parse time** and nothing in the script runs, so a `try` cannot catch them. Data-dependent errors (`column_not_found`, `cant_convert`, bad regex) are runtime and catchable.

### External commands, stdout/stderr, exit codes

```nu
^echo hi                                  # ^ forces external. Output is a BYTE STREAM; `describe` => byte stream
^ls | lines                               # split to list<string>
^sh -c "echo out; echo err >&2; exit 3" | complete
# record: {stdout: "out\n", stderr: "err\n", exit_code: 3}   <- the way to inspect failure
let r = (^cmd | complete); if $r.exit_code != 0 { error make {msg: $r.stderr} }
^sh -c "echo err >&2" e>| str trim         # pipe stderr only
^sh -c "echo o; echo e >&2" o+e>| lines    # merge both into the pipe: [o, e]
^cmd e> /dev/null ; ^cmd e> err.txt ; ^cmd o> out.txt
let cmd = "echo"; ^$cmd hi                 # command from variable
let args = [hi there]; ^echo ...$args      # spread a list into args
run-external echo hi there                 # same, command and args as data
let c = [echo a b]; run-external ...$c
"in\n" | ^tr a-z A-Z                       # string piped to external stdin
```
- **pipefail is on by default since 0.111 (blog 0.111, #17449).** Observed behaviour in this build:
  - A failing external as a **statement** aborts the whole script, silently, with that exit code: `^false; "after"` exits 1 and `"after"` never runs; `^sh -c "exit 2"; "next"` exits 2. A top-level `^grep zzz f | lines | length` prints `0` and still exits 1.
  - `let x = ^sh -c "exit 1"; "got"` also exits 1 without printing `got`. The 0.112.1 release note says "`let` ignores pipefail checks"; that did not hold for this form here.
  - Escape hatches, all verified: `| complete` (always succeeds, gives `exit_code`), `try { ... } catch { ... }`, `do -i { ... }`, `| ignore` (`^false | ignore; "after"` runs `after`, exit 0).
  - `$env.LAST_EXIT_CODE` is useless inside a script that already aborted; prefer `complete`.
  - `^cmd` returning non-zero in the middle of `a | b | c` makes the whole pipeline fail even if `c` printed output (`^sh -c "echo a; exit 1" | lines` prints `[a]`, exit 1).
- Arguments: `~` and bare globs expand (`^echo ~/foo`, `^echo *.json`), quoted strings do not (`^echo "~/foo"`); a glob **in a variable** is not expanded: `let g = "*.json"; ^echo $g` prints `*.json`; use `^echo ...(glob $g)`. Since 0.116, a `{`-initial argument is parsed as a closure/record: `^echo {a}` => `can't convert closure to string` (quote it). Inside `$"..."` write `(1 + 1)` with spaces: `^echo $"x(1 + 1)"` prints `x2`, while `$"x(1+1)"` tries to run a command `1+1`.
- Missing command: `Command foo not found` with `nu::shell::external_command`, plus a "Did you mean" list. A signal-killed child gives `nu::shell::terminated_by_signal`.
- A script is not a shell: `echo a b` is nu's `echo` returning a list; to print use `print`.

### Pipelines and `$in`

```nu
[1 2 3] | $in.0                       # $in is the pipeline value; usable at the start of any expression
5 | ($in + $in)                       # 10: $in may be used more than once (verified; both 5)
ls | if ($in | length) > 0 { "has" } else { "none" }
let x = 5 | $in + 1; $x               # 6 : `let x = <whole pipeline>`
def f [] { let a = $in; ... }          # capture $in first in a def/script
```
- In a closure, the first command receives the item both as `{|x|}` parameter **and** as `$in`/pipeline input. So `each {|f| nu-check $f}` gets the string piped in; the `$in` leak is why bare-word commands behave unexpectedly inside closures. Prefer `$f | cmd` or `cmd $f` knowing this.
- `5 | let x = $in` is a parse error; write `let x = 5`. In the middle of a pipeline `let` passes the value through, at the start it assigns and outputs nothing (0.111, blog 0.111 #17446).
- `do {|x| ...}` needs an argument: `[1 2 3] | do {|x| ...}` errors `Missing parameter: x`; call as `do {|x| $x} $in` or use `do { $in ... }`.
- Reserved variable names: `$in $nu $env $ans` (0.115), and `it` was reserved in 0.111 and re-allowed in 0.112.1.

### Operators

`+ - * / // mod ** == != < > <= >= and or not xor in not-in has not-has =~ !~ starts-with ends-with ++ ++=` and compound `+= -= *= /=`, plus (main) `older-than newer-than`. Source: `help operators`.
- Spacing is mandatory and the errors are not helpful: `5 -3` => `expected operator`; `$x+1` => `expected valid variable name. Did you mean '$x'?`; `ls |where size>1kb` => name_not_found; `ls | where size > 1 kb` => `expected operator`; `echo (1+2)` => `Command 1+2 not found`. Write `$x + 1`, `size > 1kb`, `(1 + 2)`.
- `ls ~ | length > 0` / `$env | columns | length > 3` => `extra_positional`: pipeline stages are not expressions. Use `(ls | length) > 0`, or `... | length | $in > 0`.
- Compound assignment type-checks like the plain operator (`$x /= 2` on an int errors, 0.106).

---

## 7. Pitfalls with exact errors

| Symptom (verbatim) | Cause and fix |
|---|---|
| `nu::shell::incompatible_path_access` / `byte stream doesn't support cell paths` | `open` of a file with no known extension (`flake.lock`, `.log`, `.ini`). Add `\| from json` (or `open --raw f \| from json`). |
| `nu::shell::pipeline_mismatch` / `Pipeline empty` / `no input value was piped in` | `-c`/script run without `--stdin`, so `from json` had no input. |
| `nu::parser::input_type_mismatch` / `Command does not support record<a: int> input.` | Parse-time type check (e.g. `{a:1} \| length`, `\| where`, `\| first`; `[1 2] \| columns`). Records need `items`/`transpose`/`columns`; lists need `length`/`first`. |
| `nu::shell::only_supports_this_input_type` / `Input type not supported` | Run-time input check (0.102): e.g. `lines` on `list<int>`, `str upcase` on `nothing`, `merge` table+record. Check `describe` of the input. |
| `nu::shell::column_not_found` / `Cannot find column 'x'` + help `try 'x?'` | `get`/`select`/`reject`/`update` on a missing key. Use `x?`, `get -o`, or `default`. `insert` of an existing key gives `column_already_exists`; use `upsert`. |
| `nu::shell::name_not_found` / `did you mean 'name'?` | Typo in a column on a table (`ls \| get nme`). |
| `nu::shell::access_beyond_end` / `Row number too large (max: 2)` | `[1 2 3].5`. Use `.5?`. |
| `nu::parser::operator_incompatible_types` / `Types 'string' and 'int' are not compatible for the '+' operator.` | `"1" + 1`. Convert with `into int`. |
| `nu::parser::operator_unsupported_type` / `The '++' operator does not work on values of type 'int'` | `[1] ++ 4`. Use `append 4` or `++ [4]`. Also `"a" * 3`. |
| `nu::shell::operator_overflow` | i64 arithmetic overflowed. Use `into float`. |
| `nu::parser::assignment_requires_mutable_variable` / `needs to be a mutable variable` | Use `mut`, or shadow with `let`. |
| `nu::parser::expected_keyword` / `Capture of mutable variable.` | `mut` used inside a closure. Use `for`, `reduce` or `math sum`. |
| `nu::parser::shell_andand` / `shell_oror` | `&&`, `||`. Use `;`, `and`, `or`, or `try`. |
| `nu::parser::missing_positional` / `Missing required positional argument` | Also what you get from `where type == match` (keyword) and from `-c 'def main [x] ...'` without args. |
| `nu::parser::unknown_flag` / `The 'cmd' command doesn't have flag '-1'` | Negative literal as an argument is parsed as a flag. Parenthesize: `f (-1)`, `str substring (-3)..`. Same for `default -1` (write `default (-1)`). |
| `nu::parser::parse_mismatch` / `expected operator` | Missing spaces around an operator, or `1 kb`. |
| `nu::parser::extra_positional` / `Usage: length` | A stray `> 0` after a pipeline stage. Parenthesize the pipeline. |
| `nu::shell::external_command` / `Command 'x' not found` | Typo, unavailable program, `filter`, `1month`, `else` on its own line, `cat <<EOF`. Check `help commands`, `which x`. |
| `nu::shell::not_a_constant` / `Value is not a parse-time constant` | `source $var` / `use $var`. Use `const`. |
| `nu::parser::module_not_found` | `use` path wrong; resolved at parse time relative to the file or `NU_LIB_DIRS`. |
| `nu::shell::error` / `Destination file already exists` | `save` needs `-f`. |
| `nu::shell::unsupported_input` / `no 'to' converter matches the file's extension` | `save` of structured data to unknown extension. `to json \| save`. |
| `nu::shell::delimiter_error` / `found record with 2 fields, but the previous record has 1 fields` | Ragged CSV. `from csv --flexible`. |
| `nu::shell::error` / `Error while parsing JSON text` | NDJSON given to `from json`; use `--objects`. |
| `nu::shell::http_error` / `HTTP Error 404 (Not Found)` | `--allow-errors --full` to inspect. |
| `nu::shell::io::file_not_found` from `nu-check x.nu` | Relative path not resolved against cwd. See section 1. |
| `nu::shell::recursion_limit_reached` / `Recursion limit (50) reached` | Recursive `def` deeper than 50. See section 9. |
| `nu::shell::invalid_unit` | `format filesize` unit casing. |
| `nu::shell::cant_convert` / `Can't convert to range` | `str substring 1 3`; use `1..3`. |

### Not-an-error but wrong

- `find` highlights with ANSI even when piped. `--no-highlight` or use `where`.
- `par-each` result order is arbitrary.
- `each` silently drops `null` results.
- `ls $var`, `ls "*.json"`, `open "*.json"`, `^echo $var` do not glob. `glob`, `into glob` or `...(glob ...)`.
- `from csv` infers types (`007` => `7`, `1.50` => `1.5`; use `--no-infer`). Numbers print canonicalised: `echo 1.50` prints `1.5`.
- `str length` counts bytes.
- `into datetime` of an int is nanoseconds.
- `-c` runs the user's `config.nu` and `display_output` hook; `-n` avoids it.
- Table rendering of results: piped (non-TTY) output is still box-drawn and wraps at about 80 columns; long cells are wrapped. `table -w 300`, `table -e` expand. For machine output end with `to json -r`, `to text`, `to nuon`, or `str join (char nl)`.
- Final-expression printing only applies to the last statement.
- `input` / `input list` fail without a TTY (`I/O error`; `input list` also needs input).
- `echo 5 | $in * 2` works but `echo (1+2)` does not. `echo` returns a value; it is not a printer.
- `"Hello" | str upcase` writes a deprecation warning to stderr.
- `$"$s!"` is a plain string, not interpolation.
- Unquoted `type == match` / `== def` hit keywords.
- `sort-by` on a missing column is silent.

---

## 8. Python to Nushell translation table

All verified (run on this binary). `t` is the table from section 3 unless noted.

| Python | Nushell |
|---|---|
| `json.load(open("a.json"))` | `open a.json` (extension) or `open --raw f \| from json` (unknown ext) |
| `d["deps"][0]["n"]` / `d.get("x")` | `$d.deps.0.n` / `$d.x?` / `$d \| get x? \| default "y"` |
| `[x["n"] for x in d["deps"] if x["v"] > 1]` | `$d.deps \| where v > 1 \| get n` |
| `{k: v for k, v in pairs}` | `$pairs \| into record` (list of `[k v]`), or `reduce -f {} {\|it, acc\| $acc \| merge {($it.k): $it.v}}` |
| `d.items()` | `$d \| items {\|k v\| ...}` or `$d \| transpose k v` |
| `del d["meta"]`, `{**d, "x": 1}` | `$d \| reject meta`, `$d \| merge {x: 1}` / `upsert x 1` |
| `json.dump(d, f, indent=2)` | `$d \| to json \| save -f out.json` (`to json -r` compact; `-i 4` indent) |
| `sorted(rows, key=lambda r: r["age"], reverse=True)` | `$t \| sort-by age -r` |
| `Counter(xs).most_common()` | `$xs \| uniq -c \| sort-by count -r` |
| `itertools.groupby` (sorted) | `chunk-by {...}`; dict-of-lists: `group-by col` |
| `sum(r["age"] for r in rows)` / `mean` | `$t.age \| math sum` / `math avg` / `math median` / `math stddev` |
| `set(a) & set(b)`, `-`, `\|` | `$a \| intersect $b`, `difference`, `union` (these are in this build) |
| `list(zip(a, b))`, `enumerate(xs)` | `$a \| zip $b`, `$xs \| enumerate` |
| `csv.DictReader` | `open p.csv` (types inferred; `--no-infer` keeps text) |
| `csv.writer` | `$t \| save -f o.csv` or `$t \| to csv \| save -f o.csv` |
| `re.search(p, s)` | `$s =~ 'p'` |
| `re.findall(r"(\d+)", s)` | `$s \| parse -r '(\d+)' \| get capture0` => `["1","22","333"]` |
| `re.sub(p, r, s)` | `$s \| str replace -ar 'p' 'r'` (`-a` all, `-r` regex, `$1` backrefs) |
| `re.split(p, s)` | `$s \| split row -r 'p'` (trailing separator leaves `""`) |
| `s.split(",")`, `",".join(xs)` | `split row ","`, `str join ","` |
| `s.strip()`, `.lower()`, `.upper()` | `str trim`, `str lowercase`, `str uppercase` |
| `s[1:4]`, `s[-3:]` | `str substring 1..3` (inclusive), `str substring (-3)..` |
| `f"{x:>5}"` | `$"($x)"` plus `fill -w 5 -a r` |
| `datetime.strptime(s, "%d/%m/%Y")` | `$s \| into datetime -f "%d/%m/%Y"` |
| `dt.strftime("%F")` | `$dt \| format date "%F"` |
| `datetime.now()`, `time.time()` | `date now`, `date now \| format date "%s" \| into int` |
| `(d2 - d1).days` | `($d2 - $d1) / 1day \| math floor` |
| `dt + timedelta(days=3)` | `$dt + 3day` (no month/year arithmetic) |
| `os.walk` / `Path.rglob("*.py")` | `glob **/*.py` (absolute paths) or `ls **/*.py \| get name` |
| `os.path.getsize`, `stat` | `ls f \| get size.0` (filesize), `into int` for bytes |
| `os.path.splitext/basename/join` | `path parse`, `path basename`, `path join` |
| `open(f).read()` / `.readlines()` | `open --raw f` (string) / `open f \| lines` |
| `open(f, "w").write(s)` | `$s \| save -f f` (`-a` append) |
| `shutil.copytree/move/rmtree` | `cp -r`, `mv`, `rm -r` |
| `tempfile.mkdtemp()` | `mktemp -d` |
| `sys.argv`, `argparse` | `def main [file: path, --count (-c): int = 2, ...rest]`; `--help` free |
| `os.environ["X"]`, `.get` | `$env.X`, `$env.X? \| default ""` |
| `subprocess.run(cmd, capture_output=True)` | `^cmd args \| complete` (`stdout stderr exit_code`) |
| `subprocess.check_output(cmd).decode()` | `^cmd args` (auto string when used as a value, `\| str trim`) |
| `requests.get(u).json()` | `http get $u` |
| `requests.post(u, json=d)` | `http post --content-type application/json $u $d` |
| `hashlib.sha256(s).hexdigest()` | `$s \| hash sha256` |
| `base64.b64encode` | `$s \| encode base64` / `decode base64 \| decode utf8` |
| `uuid.uuid4()` | `random uuid` |
| `random.randint(1, 6)` | `random int 1..6` |
| `time.sleep(0.5)` | `sleep 500ms` |
| `sqlite3.connect` | `open x.db \| query db "select ..."`; `into sqlite x.db -t tbl` (sqlite is built in) |
| `try/except` | `try { } catch {\|e\| $e.msg }` |
| `raise ValueError(msg)` | `error make {msg: "..."}` |
| `assert` | `use std/assert; assert ($x == 1)` |
| `int(s)`, `float(s)`, `str(n)`, `bool(s)` | `into int`, `into float`, `into string`, `into bool` |

Mini-recipes (verified):

```nu
# group + aggregate
open p.csv | group-by city --to-table | each {|g| {city: $g.city, avg: ($g.items.age | math avg)}}
# [[city, avg]; [Wien, 35.5], [Graz, 25.0]]

# update a field inside a nested list
open a.json | update deps {|r| $r.deps | where v > 1} | to json -r

# NDJSON in, filter, NDJSON out
open --raw log.jsonl | lines | each {from json} | where level == "error" | each {to json -r} | str join (char nl)

# grep-like with line numbers
^rg -n "o" h.txt --no-heading | lines | parse "{n}:{t}"

# table of file sizes
ls **/* | where type == file | sort-by size -r | first 5 | select name size

# in-place edit
open Cargo.toml | upsert package.version "0.2.0" | save -f Cargo.toml     # TOML: comments and blank lines SURVIVE in this build (verified); YAML and JSON are re-serialised and lose comments/formatting (verified)
```

---

## 9. What Nushell does badly: when Python is justified

Measured or confirmed in this build.

1. **Big integers and exact decimals.** i64 only. Overflow errors on `+ * **`; `"9223372036854775808" | into int` silently saturates to i64::MAX; `from json` silently turns an integer beyond i64 into a float (`12345678901234567890` => `12345678901234567168.0`). No `Decimal`, `Fraction`, bigint. A literal beyond i64 is a parse error.
2. **Deep recursion.** `$env.config.recursion_limit` defaults to **50** and a recursive `def` hits `nu::shell::recursion_limit_reached`. Raising it (`$env.config.recursion_limit = 100000`) worked at depth 200 and **stack-overflows the process at depth 1000** (`fatal runtime error: stack overflow`, abort). Use loops, `reduce`, `generate`.
3. **Date arithmetic beyond fixed durations.** No month/year units, no calendar math (`+ 1month` fails, building `Jan 31 + 1 month` errors). No business-day, `dateutil.relativedelta`, ISO week helpers beyond `format date` codes. `format date` names are locale-dependent.
4. **Missing parsers (plugins not installed here).** `from ini`, `eml`, `ics`, `vcf`, `html`, `query web`, polars/dataframes (`polars ...` => `Command not found`), `ods/xlsx` exist but are niche. No `pandas`, `numpy`, matplotlib. The large `matrix` family exists but is small-scale.
5. **Binary formats and protocols.** `bytes`, `bits`, `into binary`, `format bits`, `encode/decode` exist; no `struct.unpack`, no sockets, no `zipfile/tarfile` builtins (shell out to `tar`, `gzip`, `zip`; `unzip` was not installed). Only `http get/post/put/patch/delete/head/options`: no sessions, cookies, retries, multipart upload, streaming bodies you can iterate with backpressure, websockets, async. Concurrency is `par-each` and `job spawn`/`job send`/`job recv` only.
6. **No heredocs, no multi-line single-statement ergonomics in `-c` from bash.** Use `nu /dev/stdin <<'EOF'` or raw strings `r#'...'#`. `'` has no escape inside `'...'`.
7. **Non-UTF-8 text.** Strings are UTF-8. Other encodings work through `open --raw f | decode iso-8859-1` (also big5, euc-jp, gbk, utf-16, cp1252, ... per `help decode`; verified `latin-1` round trip) and `encode`. `lines` replaces invalid bytes (0.114). There is no auto-detection (no chardet).
8. **Machine-readable default output.** A bare table result is box-drawn text, wrapped at about 80 cols when not a TTY, and the user's `display_output` hook can change it. Always end with `to json -r`/`to text`/`print`. `input`, `input list`, `explore`, `tui` need a TTY.
9. **Locale.** `format date` weekday/month names follow `$env.LANG`/`LC_ALL`.
10. **Unicode algorithms.** `str length` is bytes (graphemes with `-g`), `str lowercase` of `İ` gives 3 bytes, `sort` is codepoint order not locale collation (`sort --natural` only for digit runs). No normalisation (NFC/NFD), no `unicodedata`.
11. **Numeric computing.** Only `math` basics (`avg median stddev variance sum product min max mode, trig, ln, sqrt`). No FFT, linear algebra, optimisation, random distributions, seeded RNG control.
12. **Libraries and typing.** No package manager and no ecosystem: modules are local `.nu` files or `std`. Closures cannot mutate outer `mut` variables. Types are structural and checked at parse time; dynamic dispatch and classes do not exist. Large-data performance: `1..1000000 | reduce` and `1..200000 | each` complete within seconds, but nu is an interpreter with copy semantics; heavy numeric loops are orders of magnitude slower than numpy.
13. **Round-trip fidelity.** `open x.yaml | upsert ... | save -f x.yaml` and the same for JSON drop comments and original layout (verified: `# c` and `# t` vanished, JSON re-indented). TOML edits through `open x.toml | upsert ... | save -f` kept comments and blank lines in this build (verified; not documented in any release note, so do not rely on it across versions). Number formatting is canonicalised (`1.50` => `1.5`). For textual edits use the Edit tool.
14. **Stability.** Command flags and semantics move every 4 to 6 weeks (sections below). Anything not run on the installed binary should be treated as suspect.

---

## 10. Version history: renames, removals, behaviour changes (0.100 to this build)

`blog N` = https://www.nushell.sh/blog/<date>-nushell_v0_<N>_0.html (see index). **[main]** = after 0.116.1, in this binary only.

| Item | Old | New | Release |
|---|---|---|---|
| Division | int/int truncated | `/` always float; `mod` floor-based; overflow errors | 0.100 |
| `http --max-time` | int seconds | duration (`2sec`) | 0.100 |
| `url parse` params | record | table of `{key value}` | 0.100 |
| `++` | any append | lists/strings/binary only; use `append` | 0.101 |
| `group-by` | one key | many keys, `--to-table` | 0.101 |
| `ls` order | unsorted | sorted by name | 0.101 |
| `timeit` | block | closure only | 0.101 |
| `du` | `-a` flag, wide output | condensed, `--long` | 0.101 |
| `from` commands | set `content_type` | drop it | 0.101 |
| custom command types | `-> string` | `: any -> string` required form | 0.101 |
| `date to-record`, `date to-table`, `split-by` | deprecated | **removed** 0.102 | 0.101 to 0.102 |
| `utouch` | | renamed `touch` | 0.102 |
| pipeline input types | parse-time only | also run-time (`only_supports_this_input_type`) | 0.102 |
| `format filesize` unit | case-insensitive | case-sensitive (`kB`, `MiB`) | 0.102 |
| `range`, `into bits`, `fmt` | deprecated 0.102 | **removed**; use `slice`, `format bits`, `format number` | 0.103 |
| `match` arm returning a closure | ran it | returns the closure | 0.103 |
| `split list` | dropped empty sublists | keeps them | 0.103 |
| `to json`/`msgpack` of a closure | `null` | error (`--serialize` to stringify) | 0.103 |
| `from xml` | parsed DTDs | DTD off unless `--allow-dtd` | 0.103 |
| `into datetime` human strings (`"tomorrow"`) | worked | removed; `date from-human`; **works again [main]** #19398 | 0.104 / main |
| `do -s -p` | deprecated | removed; `-i` | 0.104 |
| `describe` of datetime | `date` | `datetime` | 0.104 |
| cell paths | case-insensitive | case-sensitive, `!` for insensitive | 0.105 |
| `filter` | | deprecated 0.105; **removed [main]** #19382; use `where` (accepts stored closures) | 0.105 / main |
| `http get :8000` | | adds `http://localhost` | 0.105 |
| `get/select/reject --ignore-errors (-i)` | | `--optional (-o)` (0.106); **-i removed [main]** #19382 | 0.106 / main |
| `path`-typed params | made absolute | left as given (`..` `~` expanded) | 0.106 |
| `parse` unmatched optional group | `""` | `null` | 0.106 |
| float display | `2` | `2.0` | 0.106 |
| `find` | case-insensitive by default | case-sensitive; `--ignore-case`/`-i` | 0.107 |
| `each` with `null` input | called closure | returns null | 0.107 |
| `format bits` | native endian | big endian | 0.107 |
| `bytes at`/`first`/`skip`/`take`/`str substring` | kept `content_type` | drop it | 0.107 |
| `random dice` | builtin | deprecated 0.107, removed 0.112.1; `use std/random` | 0.107 / 0.112.1 |
| `into value` string inference | | `detect type` (0.108); inference dropped (0.112.1) | 0.108 / 0.112.1 |
| `**` | left-assoc | right-assoc | 0.108 |
| `break`/`continue` outside loop | runtime panic | compile error | 0.108 |
| `reorder-cell-paths` | opt-in | on by default | 0.108 |
| `first`/`last` on empty | error | `null` (`--strict` errors) | 0.109 |
| `update b? 2` on missing | error | no-op | 0.109 |
| `$nu.temp-path`/`home-path` | | `$nu.temp-dir`/`home-dir` | 0.110 |
| `error make` | single `label` | `label` (one) + `labels` (many) | 0.110 |
| `mv`/`cp`/`du` glob `*` | matched dotfiles | not unless `-a` | 0.110 |
| **pipefail** | opt-in | **on**: failing external aborts script | 0.111 |
| `let` mid/start of pipeline | | start assigns silently; mid passes through | 0.111 |
| env var names | case-sensitive on unix | case-insensitive lookup | 0.111 |
| `is-empty` on empty pipeline | | returns bool | 0.111 |
| `job tag` | | `job describe` | 0.112.1 |
| `open x.md` | string | parsed AST table (`--raw` for text) | 0.112.1 |
| `watch --debounce-ms`, `metadata set --merge` | | removed (0.112.1); `--debounce`, closure form | 0.112.1 |
| `parse` on a stream | split by line | **no** implicit split; pipe `lines` first | 0.113 |
| `mkdir -v`, `mv -v`, `rm -v` | string | tables | 0.113 |
| `kill -9 PID` | | `kill -s 9 PID` | 0.113 |
| `try ... finally` | | `finally` result unused, errors not suppressed | 0.113 |
| `use foo` | exposed submodules | needs `export use sub` | 0.114 |
| error record `json` field | | removed; `details` | 0.114 |
| `str upcase`/`str downcase` | | deprecated; `str uppercase`/`lowercase` (still run, warn) | 0.114 |
| `enforce-runtime-annotations` | opt-in | on | 0.114 |
| `lines` | | replaces invalid UTF-8; `--strict` | 0.114 |
| `flatten` collisions | overwrote | `<parent>_<field>` | 0.114 |
| `--` | | ends option parsing | 0.114 |
| `from yaml` | YAML 1.1 | YAML 1.2; `--spec 1.1`; unknown tags error | 0.115 |
| `$ans` | | reserved name | 0.115 |
| `group-by` null | `""` | omitted in record output | 0.115 |
| `to yaml --compact-list-indent` | | `--list-indent compact\|indented` | 0.116 |
| `^echo {a}` | literal | closure/record parse | 0.116 |
| `[[a b];]`, `[1 2;]` | accepted | parse error | 0.116 |
| `let-env`, `date format`, `fetch`/`post`/`benchmark` hints, `get -s`, `positional` completer option | stubs | removed | **[main]** #19382 |
| `into datetime --formats`, `older-than`/`newer-than`, `from/to dotenv`, `uniq --keep-last` | | new | **[main]** #19413, #19397, #19391, #19326 |
| `math sum` etc. on a table column | | sums the column | **[main]** #19414 |

Primary-source URLs for these rows: the blog post of the named release. Full URL list: 0.100 `2024-11-12-nushell_0_100_0`, 0.101 `2024-12-24-nushell_0_101_0`, 0.102 `2025-02-04-nushell_0_102_0`, 0.103 `2025-03-18-nushell_0_103_0`, 0.104 `2025-04-29-nushell_0_104_0`, 0.105 `2025-06-10-nushell_0_105_0`, 0.106 `2025-07-23-nushell_0_106_0`, 0.107 `2025-09-02-nushell_0_107_0`, 0.108 `2025-10-15-nushell_v0_108_0`, 0.109 `2025-11-29-nushell_v0_109_0`, 0.110 `2026-01-17-nushell_v0_110_0`, 0.111 `2026-02-28-nushell_v0_111_0`, 0.112.1 `2026-04-11-nushell_v0_112_1`, 0.113 `2026-05-23-nushell_v0_113_0`, 0.114 `2026-07-04-nushell_v0_114_0`, 0.115 `2026-08-15-nushell_v0_115_0`, 0.116 `2026-09-26-nushell_v0_116_0`, 0.116.1 `2026-10-04-nushell_v0_116_1`, all under `https://www.nushell.sh/blog/`. 0.112.0 was skipped (crates failed to release).

---

## 11. Not verified, or verified only partly

- Exact provenance beyond the flake rev: the binary is a Nix build of upstream main; whether it is exactly `e6b30c87a` was inferred from `flake.lock`, not from `nu --version` (prints `0.116.2`, no commit hash).
- `let x = ^cmd` under pipefail contradicts the 0.112.1 note ("`let` ignores pipefail checks"). Observed exit 1; the note may refer to a different form (e.g. `let x = (cmd | complete)`), not checked further.
- `http post -t json URL {record}` type-mismatched (`Accepted types: [binary, string]`); `--content-type application/json` works. Semantics of `-t` not investigated.
- Windows and macOS behaviour (everything here ran on Linux). `kill`, path handling, `PATHEXT` notes are from release notes only.
- Release-note statements not re-run: `bits shl` defaults, `from xlsx/ods`, `idx`, `tui`, `matrix`, completions/keybinding changes, MCP server notes, plugin-API changes.
- `NU_EXPERIMENTAL_OPTIONS` / `--experimental-options` toggling (e.g. `pipefail=false`) was not executed.
- Blog 0.107 claims `split column` default names start at 0, its own example shows `column1`; this binary prints `column0`/`column1`.
- Blog posts for 0.112.0 (skipped), 0.112.2, 0.113.1, 0.114.1 were not read; 0.115.1 and 0.116.1 were skimmed.
