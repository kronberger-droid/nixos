# The sandbox's side of a grant: ask, wait, print the answer.
# agent-sandbox-grants.nix puts the settings in front of this text.

usage() {
  cat >&2 <<EOF
usage: claude-sandbox-request <path | @source[:arg]> [span] [reason...]

Asks for temporary read access to something this account cannot read.
A path is mounted read-only under $GRANTS_DIR; a snapshot
source (@journal:<unit>, @journal-boot) is copied there. Both go away
when the span is over. Span defaults to $DEFAULT_SPAN and is capped at $MAX_SPAN.

The request waits for an answer, on some hosts for up to $((QUEUE_TIMEOUT / 60)) minutes.
Exit status 0 means granted, and the path is on the last line.
EOF
  exit 2
}

[ $# -ge 1 ] || usage
case $1 in -h | --help) usage ;; esac

target=$1
span=${2:-}
shift
[ $# -eq 0 ] || shift
reason=$*

# Made absolute, not resolved: resolving is the broker's job, done with
# the approver's eyes.
if [[ $target != @* ]] && [[ $target != /* ]]; then target=$PWD/$target; fi

if [ ! -S "$SOCKET" ]; then
  echo "claude-sandbox-request: no broker is listening at $SOCKET" >&2
  exit 1
fi

last=""
# -t: socat gives up that long after its input ends, and the input ends
# with the request, long before a person has answered.
while IFS= read -r line; do
  printf '%s\n' "$line"
  last=$line
done < <(printf '%s\n' "$target" "$span" "$reason" |
  socat -t "$((QUEUE_TIMEOUT + 60))" - "UNIX-CONNECT:$SOCKET")

[[ $last == granted* ]]
