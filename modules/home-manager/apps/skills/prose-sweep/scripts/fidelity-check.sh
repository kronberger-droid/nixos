#!/bin/sh
# List numbers and markup tokens the uncommitted diff removes without putting
# back in the same hunk. Run from inside the document's repository.
# Usage: fidelity-check.sh FILE...
# Output: file:line: token
# A token here is either explained by the change list or restored. Empty
# output means every number, symbol, label and reference survived.
set -u

if [ $# -eq 0 ]; then
  echo "usage: fidelity-check.sh FILE..." >&2
  exit 2
fi

git diff -U0 --word-diff=porcelain --word-diff-regex='[^[:space:]]+' -- "$@" | awk '
  function norm(w) { sub(/[.,;:!?]+$/, "", w); return w }
  function flush(   w) {
    for (w in removed)
      if (!(w in added)) print file ":" line ": " w
    split("", removed); split("", added)
  }
  /^diff --git / { flush(); header = 1; next }
  header && /^\+\+\+ / { file = substr($0, 7); next }
  /^@@ / {
    flush(); header = 0
    line = $3; sub(/^\+/, "", line); sub(/,.*/, "", line)
    next
  }
  header { next }
  /^-/ {
    n = split(substr($0, 2), t, /[[:space:]]+/)
    for (i = 1; i <= n; i++) {
      w = norm(t[i])
      if (w ~ /[0-9@\\#$<>{}\[\]_^=%]/) removed[w] = 1
    }
    next
  }
  /^\+/ {
    n = split(substr($0, 2), t, /[[:space:]]+/)
    for (i = 1; i <= n; i++) added[norm(t[i])] = 1
    next
  }
  END { flush() }
'
