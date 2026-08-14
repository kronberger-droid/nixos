# waybar helper scripts, nushell edition

One-for-one ports of the `.sh` files in the parent directory. Both sets take
the same `@placeholder@` variables; which one backs a given button is decided
by `scriptLang` in `waybar.nix`.

Two conventions run through all of them:

**Every fallible external goes through `complete`.** Unlike bash, nushell
treats a non-zero exit from an external as an error that aborts the script, and
`pgrep` with no match, `systemctl is-active` on a stopped unit and `pkill` with
nothing to kill all exit non-zero in normal operation. So `(^cmd |
complete).exit_code == 0` when the code is the answer, `^cmd | complete |
ignore` when it is not.

**JSON is built as a record.** `{text: ..., class: ...} | to json --raw`
replaces the hand-quoted strings and `from json` replaces jq, which is what
lets these drop `jq`, `ripgrep`, `sd`, `gnugrep` and most of `coreutils`.

Glyphs are `\u{f1f6}` escapes so the sources stay ASCII; `to json` emits them
as UTF-8, which waybar parses the same as the `\uXXXX` the bash versions used.

Lint with `nu -n --ide-check 20 <file>` (empty output means clean).
