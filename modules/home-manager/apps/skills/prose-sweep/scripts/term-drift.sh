#!/bin/sh
# Print every non-canonical variant listed in the glossary's Terms table.
# Usage: term-drift.sh GLOSSARY FILE...
# Output: file:line: variant -> canonical
# Then every "<number> <plural noun>" phrase grouped by noun, so
# decompositions that change size between chapters stand out.
set -u

if [ $# -lt 2 ]; then
  echo "usage: term-drift.sh GLOSSARY FILE..." >&2
  exit 2
fi

glossary=$1
shift

# Rows of the Terms table: "| canonical | v1; v2 | where |".
pairs=$(awk -F'|' '
  /^## / { in_terms = ($0 ~ /^## Terms/); next }
  in_terms && /^\|/ {
    canon = $2; vars = $3
    gsub(/\?/, "", canon); gsub(/^ +| +$/, "", canon)
    if (canon == "" || canon == "Canonical" || canon ~ /^-+$/) next
    n = split(vars, v, ";")
    for (i = 1; i <= n; i++) {
      gsub(/^ +| +$/, "", v[i])
      if (v[i] != "") print v[i] "\t" canon
    }
  }
' "$glossary")

if [ -z "$pairs" ]; then
  echo "no variants found in the Terms table of $glossary" >&2
fi

printf '%s\n' "$pairs" | while IFS="$(printf '\t')" read -r variant canon; do
  [ -n "$variant" ] || continue
  grep -HniwF -- "$variant" "$@" 2>/dev/null |
    awk -F: -v v="$variant" -v c="$canon" '{ print $1 ":" $2 ": " v " -> " c }'
done

echo "== decompositions"
grep -HnoiE '\b(two|three|four|five|six|seven|eight|nine|ten|[2-9]) [a-z]+(s|es)\b' "$@" 2>/dev/null |
  awk -F: '{ split(tolower($3), w, " "); print w[2] "\t" w[1] " " $1 ":" $2 }' |
  sort | awk -F'\t' '
    $1 != prev { if (prev != "") print ""; printf "%s:", $1; prev = $1 }
    { printf " %s;", $2 }
    END { if (prev != "") print "" }
  '
