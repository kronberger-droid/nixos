# The primary user's side of the grants: answer a waiting request from a
# terminal, see what is open, close one early. agent-sandbox-grants.nix
# puts the settings in front of this text.
#
# This is the whole approval path where there is no compositor, and the
# fallback over ssh where there is one. The grant itself still goes
# through sudo to the root helper, so on a host that asks for a password
# this asks for it.

die() {
  echo "claude-sandbox-grant: $*" >&2
  exit 1
}

# The queue belongs to the primary user. Anyone else allowed to answer
# (the phone's account on the homeserver) gets there through a sudo rule
# for this command, run as him. "$0" is the path the rule names when the
# command was called by name.
if [ "$(id -un)" != "$PRIMARY_USER" ]; then
  exec "$SUDO" -u "$PRIMARY_USER" "$0" "$@"
fi

pending=()
load_pending() {
  [ -f "$STATE/pending" ] || die "no request is waiting"
  mapfile -t pending <"$STATE/pending"
}

show_pending() {
  echo "request ${pending[0]}: ${pending[2]} for ${pending[-1]}"
  [ -z "${pending[3]}" ] || echo "  claude says: ${pending[3]}"
}

decide() {
  printf '%s\n' "${pending[0]}" "$@" >"$STATE/decision.new"
  mv "$STATE/decision.new" "$STATE/decision"
}

case "${1:-list}" in
  list)
    if [ -f "$STATE/pending" ]; then
      load_pending
      show_pending
    fi
    [ ! -e "$STATE/locked" ] || echo "requests are locked after repeated denials: claude-sandbox-grant reset"
    "$HELPER" list
    ;;
  approve | deny)
    verb=$1
    load_pending
    if [ -n "${2:-}" ]; then
      [ "$2" = "${pending[0]}" ] || die "the waiting request is ${pending[0]}, not $2"
    elif [ -t 0 ]; then
      show_pending
      if [ "$verb" = approve ]; then
        read -r -p "Grant this? [y/N] " answer
        [[ $answer == [yY] ]] || verb=deny
      fi
    else
      die "say which request: claude-sandbox-grant $verb ${pending[0]}"
    fi
    if [ "$verb" = deny ]; then
      decide denied
      echo "denied"
      exit 0
    fi
    rc=0
    out=$("$SUDO" "$HELPER" "${pending[@]:4}") || rc=$?
    case $rc in
      0) decide granted "$out" ;;
      3) decide refused "$out" ;;
      # sudo itself failed, a mistyped password say. The request keeps
      # waiting, so this can be run again.
      *) die "the grant did not go through; the request is still waiting" ;;
    esac
    echo "$out"
    ;;
  revoke)
    [ $# -eq 2 ] || die "usage: claude-sandbox-grant revoke <name>"
    "$SUDO" "$HELPER" revoke "$2"
    ;;
  reset)
    rm -f "$STATE/locked" "$STATE/denials" "$STATE"/denied-*
    echo "denials cleared"
    ;;
  *)
    die "usage: claude-sandbox-grant [list | approve [id] | deny [id] | revoke <name> | reset]"
    ;;
esac
