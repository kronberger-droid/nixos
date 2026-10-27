#!/bin/sh
# Print candidate hits per mechanical category, with counts.
# Usage: mechanical-grep.sh FILE...
# Categories match references/mechanical.md. Hits are candidates; read each
# one in context before changing anything.
set -u

if [ $# -eq 0 ]; then
  echo "usage: mechanical-grep.sh FILE..." >&2
  exit 2
fi

total=0

check() {
  name=$1
  flags=$2
  pattern=$3
  shift 3
  hits=$(grep -Hn $flags -E -- "$pattern" "$@" 2>/dev/null)
  if [ -n "$hits" ]; then
    count=$(printf '%s\n' "$hits" | wc -l)
  else
    count=0
  fi
  total=$((total + count))
  echo "== $name ($count)"
  [ -n "$hits" ] && printf '%s\n' "$hits"
}

check dash -o '—|–| -- ' "$@"
check antithesis -oi '\bnot (only|just|merely)\b.*\bbut\b|\brather than\b|\bmore than just\b|\bon (the )?one hand\b|\bon the other hand\b|, not [a-z0-9]' "$@"
check closer -oi '\ba testament to\b|\bat (its|the) (heart|core)\b|\bthe (key|real) (insight|question|point) is\b|\bwhat really matters\b|\bthis (shows|underscores|highlights) the importance\b' "$@"
check ai-words -oi '\b(additionally|align(s|ed)? with|bolster(ed|s)?|crucial|deep dive|delv(e|es|ed|ing)|enduring|enhanc(e|es|ed|ing)|garner(s|ed)?|highlight(s|ed|ing)?|interplay|intricac(y|ies)|intricate|landscape|meticulous(ly)?|pivotal|showcas(e|es|ed|ing)|tapestry|testament|underscor(e|es|ed|ing)|vibrant)\b' "$@"
check intensifier -oi '\bin effect\b|\bin a sense\b|\bin essence\b|\btruly\b|\bgenuinely\b|\bsimply\b|\bessentially\b|\bfundamentally\b|\breally\b|\bin fact\b|\bindeed\b|\bactually\b|\bexactly\b|\bprecisely because\b' "$@"
check adjective -oi '\bnovel\b|\bimpressive\b|\bpromising\b|\bcomprehensive\b|\brobust\b|\bpowerful\b|\bstate-of-the-art\b|\bparadigm\b|\bleverag(e|es|ed|ing)\b|\butiliz(e|es|ed|ing|ation)\b' "$@"
check significant -oi '\bsignifican(t|tly|ce)\b|\bsubstantial(ly)?\b' "$@"
check opener -n '(^|[.!?] +)(Moreover|Furthermore|Additionally|Notably|Importantly|Ultimately|Crucially|That said|It is worth noting that|It should be noted that)\b|\bIn this (chapter|section|thesis|work),? we\b' "$@"
check metaphor -oi '\bunder the hood\b|\bdraws? (its|their) power from\b|\bwhere [a-z]+ meets [a-z]+\b|\bthe machine that\b' "$@"
check hype -oi '\bunlocks?\b|\bpowers\b|\bpromises to\b|\bstands? to\b|\bis poised to\b|\bopens the door to\b|\bhas the potential to\b|\bstands? in the way of\b' "$@"
check qualifier -oi '\b(rather|very|pretty|quite|somewhat|fairly|certainly)\b' "$@"
check ordinal -oi '\b(thusly|overly|firstly|secondly|thirdly)\b|\b[a-z]+wise\b' "$@"
check exclaim -o '[a-z)][!]( |$)' "$@"
check pompous -oi '\bfinaliz(e|es|ed|ing)\b|\b[a-z]+-oriented\b|\bmeaningful\b|\binsightful\b|\bpossess(es|ed)?\b|\bimpact(s|ed|ing)\b|\bcurrently\b' "$@"
check verb -oi '\b(orchestrat(e|es|ed|ing)|harness(es|ed|ing)?|forg(e|es|ed|ing)|weav(e|es|ing)|wove|usher(s|ed)? in|grappl(e|es|ed|ing) with|unpack(s|ed|ing)?|marshal(s|led|ling)?|anew|afresh)\b' "$@"
check wordiness -oi '\bthe fact that\b|\bas to whether\b|\bin order to\b|\bthe reason .* is because\b|\bowing to the fact that\b|\bin a [a-z]+ manner\b|\bin terms of\b|\bone of the most\b|\bit should be noted\b|\bit is important to (note|mention)\b' "$@"
check pairs -oi '\bcomprised of\b|\bdata is\b|\bdifferent than\b|\bvery unique\b|\bdue to\b|\bless [a-z]+s\b|\bimpl(y|ies|ied)\b|\binfer(s|red)?\b|\baffect|\beffect' "$@"
check passive -oi '\b(is|are|was|were|be|been|being) ([a-z]+ed|done|made|shown|given|taken|held|built|drawn|chosen|written|known|found|seen|set|put|sent|kept|run|used)\b' "$@"
check l1 -oi '\beventually\b|\bactual\b|\bsensible\b|\brespectively\b|, that\b|\binformations\b|\bresearches\b|\bevidences\b|\bequipments\b|(^|[.] +)Also\b' "$@"

echo "== total ($total)"
