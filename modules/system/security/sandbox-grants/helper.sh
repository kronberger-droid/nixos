# The root side of a sandbox grant. agent-sandbox-grants.nix puts the
# settings (the upper-case names and snapshot_source) in front of this text.
#
# Everything the caller says is checked again here, whoever the caller is:
# the broker's own check only decides whether a prompt is worth showing.
#
#   check <path>                    may this be granted? No root needed.
#   check-snapshot <source> <arg>   the same for a snapshot source.
#   grant <path> <span>             mount <path> read-only for the sandbox.
#   snapshot <source> <arg> <span>  copy a declared command's output.
#   revoke <name>                   close one grant; what the timer runs.
#   list                            the grants that are open.
#
# `--auto` in front of a verb narrows it to the auto-approve list. The
# passwordless sudo rule names a wrapper that always passes it.

die() {
  echo "claude-sandbox-grant-helper: $*" >&2
  exit 1
}

# A refusal by policy goes to stdout with its own exit status: the broker
# relays the sentence to the agent, and tells it apart from a denial.
refuse() {
  echo "refused: $*"
  exit 3
}

need_root() {
  [ "$(id -u)" -eq 0 ] || die "$1 needs root"
}

# Is $1 the path $2 or something below it?
under() {
  [ "$2" = / ] || [ "$1" = "$2" ] || [[ $1 == "$2"/* ]]
}

# C locale, so the microseconds line reads "us:" whatever LANG is.
secs() {
  LC_ALL=C systemd-analyze timespan "$1" 2>/dev/null |
    awk '$1 == "us:" { print int($2 / 1000000) }'
}

# Sets `seconds` from a span, capped at MAX_SPAN. Not through a command
# substitution: a refusal inside one would only leave the subshell.
seconds=0
span_seconds() {
  local span=$1 want max
  [[ $span =~ ^[0-9a-zA-Z.\ ]+$ ]] || refuse "not a time span: $span"
  want=$(secs "$span") || want=""
  if [ -z "$want" ] || [ "$want" -le 0 ]; then
    refuse "not a time span: $span"
  fi
  max=$(secs "$MAX_SPAN")
  [ "$want" -le "$max" ] || want=$max
  seconds=$want
}

is_auto() {
  local a
  for a in "${AUTO_PATHS[@]}"; do
    if under "$1" "$a"; then return 0; fi
  done
  return 1
}

# Refuses unless the canonical path $1, owned by uid $2, may be granted.
#
# Two zones are open. What the primary user owns inside his home, since a
# grant there hands over nothing his own processes could not already read.
# And the declared system paths, for everything owned by root or a service
# account: without that list, whoever can run this helper reads any file on
# the machine through the sandbox account.
#
# The deny list cuts both ways. A path below an entry is refused, and so is
# a path above one, because the mount would carry the entry along.
policy() {
  local p=$1 owner=$2 d ok=""
  for d in "${WRITABLE[@]}"; do
    if under "$p" "$d"; then
      refuse "the sandbox already has $d"
    fi
  done
  for d in "${DENY[@]}"; do
    if under "$p" "$d"; then
      refuse "$d is never granted"
    fi
    if under "$d" "$p"; then
      refuse "$p contains $d, which is never granted; ask for something narrower"
    fi
  done
  if [ "$owner" = "$(id -u "$PRIMARY_USER")" ] && under "$p" "$PRIMARY_HOME" &&
    [ "$p" != "$PRIMARY_HOME" ]; then
    ok=1
  fi
  for d in "${SYSTEM_PATHS[@]}"; do
    if under "$p" "$d"; then ok=1; fi
  done
  [ -n "$ok" ] || refuse "$p is outside what can be granted"
  if [ -n "$auto" ] && ! is_auto "$p"; then
    refuse "$p is not on the auto-approve list"
  fi
  return 0
}

# What snapshot_source fills in for a declared source: its command, the
# pattern its one argument has to match (empty for none), and whether it
# is granted without asking.
snap_cmd=()
snap_pattern=""
snap_auto=""

# Looks up the declared source $1 and checks its argument $2.
snapshot_policy() {
  local src=$1 arg=$2
  snapshot_source "$src" || refuse "no snapshot source named $src"
  if [ -z "$snap_pattern" ]; then
    [ -z "$arg" ] || refuse "@$src takes no argument"
  else
    [[ $arg =~ ^($snap_pattern)$ ]] || refuse "@$src: not an argument it accepts: $arg"
  fi
  if [ -n "$auto" ] && [ -z "$snap_auto" ]; then
    refuse "@$src is not auto-approved"
  fi
  return 0
}

# A name for the entry in GRANTS_DIR, chosen here and never by the caller:
# what the source is called, made safe for a unit name, plus four hex
# digits so two grants of the same thing do not collide.
name=""
make_name() {
  local base
  base=$(printf %s "$1" | tr -c 'A-Za-z0-9_.' '_' | sed 's/^[^A-Za-z0-9]*//' | cut -c1-40)
  name="${base:-grant}-$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')"
  if [ -e "$GRANTS_DIR/$name" ] || [ -e "$STATE_DIR/$name" ]; then
    die "name collision, try again"
  fi
}

room_left() {
  local live
  live=$(find "$STATE_DIR" -mindepth 1 -maxdepth 1 -type f | wc -l)
  [ "$live" -lt "$MAX_GRANTS" ] || refuse "$MAX_GRANTS grants are open already"
}

# The end of a grant is a transient timer in PID 1, so it outlives the
# broker and this process. On the wall clock, not --on-active: a monotonic
# timer stands still while a laptop sleeps, and a grant would stay open for
# however long the lid was shut. A calendar timer that came due during
# suspend fires on resume.
schedule() {
  local name=$1 until=$2
  systemd-run --quiet --unit="claude-sandbox-grant-$name" \
    --on-calendar="$(date -u -d "@$until" '+%Y-%m-%d %H:%M:%S UTC')" \
    --timer-property=AccuracySec=1s \
    -- "$(realpath -- "$0")" revoke "$name"
}

record() {
  local name=$1 kind=$2 until=$3 source=$4
  printf '%s\n' "$kind" "$until" "$source" >"$STATE_DIR/$name"
  echo "granted $GRANTS_DIR/$name until $(date -d "@$until" '+%H:%M:%S')"
}

grant() {
  local p=$1 fd owner_uid owner_gid inode mp until
  need_root grant
  [[ $p == /* ]] || refuse "not an absolute path"
  [ "$(realpath -e -- "$p" 2>/dev/null)" = "$p" ] || refuse "not a canonical path: $p"
  if [ ! -d "$p" ] && [ ! -f "$p" ]; then
    refuse "neither a directory nor a regular file: $p"
  fi

  # Hold the inode, then ask the kernel where it is. Every later decision
  # is about this descriptor, so swapping a path component for a symlink
  # between the check and the mount changes nothing that was checked. The
  # mount itself still goes by path, which the comparison below settles.
  exec {fd}<"$p"
  [ "$(readlink "/proc/self/fd/$fd")" = "$p" ] || refuse "$p moved while being checked"
  read -r owner_uid owner_gid inode < <(stat -L -c '%u %g %d:%i' "/proc/self/fd/$fd")
  policy "$p" "$owner_uid"
  span_seconds "$2"
  room_left

  make_name "$(basename -- "$p")"
  mp=$GRANTS_DIR/$name
  if [ -d "$p" ]; then mkdir -- "$mp"; else : >"$mp"; fi

  # One owner is mapped onto the sandbox account, and that is the grant:
  # files of his show up as the sandbox's own, so the owner bits decide,
  # ahead of any ACL entry naming the sandbox group. Every other owner in
  # the tree is unmapped and falls to the `other` bits. The kernel refuses
  # a uid map without a gid map, hence both.
  #
  # ro and the id map are set on the detached mount before it is attached,
  # so there is no writable moment. private: /run is shared, and a plain
  # bind would join the source's peer group (see the vault mount in
  # agent-sandbox.nix). Not recursive: mounts below the source stay out.
  #
  # ro does not stop a connect() to a socket inside the tree. That is why
  # the zones in `policy` keep /run/user out altogether.
  if ! mount --bind -o "ro,nosuid,nodev,noexec,private,X-mount.idmap=u:$owner_uid:$(id -u "$SANDBOX_USER"):1 g:$owner_gid:$(id -g "$SANDBOX_USER"):1" \
    -- "$p" "$mp"; then
    rmdir -- "$mp" 2>/dev/null || rm -f -- "$mp"
    die "mount failed for $p"
  fi
  if [ "$(stat -c '%d:%i' -- "$mp")" != "$inode" ]; then
    umount -- "$mp"
    rmdir -- "$mp" 2>/dev/null || rm -f -- "$mp"
    die "$p changed under the mount"
  fi
  exec {fd}<&-

  until=$(($(date +%s) + seconds))
  # Never a grant without its end.
  if ! schedule "$name" "$until"; then
    umount -- "$mp"
    rmdir -- "$mp" 2>/dev/null || rm -f -- "$mp"
    die "could not schedule the end of the grant"
  fi
  record "$name" mount "$until" "$p"
}

# A copy, for what is not a file: the journal, a command's output. Only
# commands declared in the nix config run here, with at most one argument
# that has to match the source's pattern. Nothing from the request is ever
# executed.
snapshot() {
  local src=$1 arg=$2 tmp until
  need_root snapshot
  snapshot_policy "$src" "$arg"
  span_seconds "$3"
  room_left

  make_name "$src${arg:+-$arg}"
  # GRANTS_DIR belongs to root, so the copy can be written in place: the
  # sandbox reads it only once it is complete and handed over.
  tmp=$(mktemp "$GRANTS_DIR/.snapshot.XXXXXX")
  [ -z "$arg" ] || snap_cmd+=("$arg")
  # The size cap is the point of `head`; it ends the command early with
  # SIGPIPE, which is no failure here.
  { timeout 60 "${snap_cmd[@]}" 2>&1 || true; } | head -c "$SNAPSHOT_MAX_BYTES" >"$tmp" || true
  chown "$SANDBOX_USER": "$tmp"
  chmod 0400 "$tmp"
  mv -T -- "$tmp" "$GRANTS_DIR/$name"

  until=$(($(date +%s) + seconds))
  if ! schedule "$name" "$until"; then
    rm -f -- "$GRANTS_DIR/$name"
    die "could not schedule the end of the grant"
  fi
  record "$name" snapshot "$until" "@$src${arg:+:$arg}"
}

# The sandbox account's processes with a working directory, a root or an
# open file inside the mount $1.
holders() {
  local mp=$1 sandbox_uid dir link target
  sandbox_uid=$(id -u "$SANDBOX_USER")
  for dir in /proc/[0-9]*; do
    [ "$(stat -c %u "$dir" 2>/dev/null)" = "$sandbox_uid" ] || continue
    for link in "$dir/cwd" "$dir/root" "$dir"/fd/*; do
      target=$(readlink "$link" 2>/dev/null) || continue
      if under "$target" "$mp"; then
        echo "${dir#/proc/}"
        break
      fi
    done
  done
}

# Linux has no revoke: a mount that is still in use cannot be unmounted,
# and a lazy unmount leaves every open descriptor and working directory
# reading on. So whatever holds the grant open goes first, and the lazy
# unmount is the last resort, logged.
revoke() {
  local name=$1 kind mp pids
  need_root revoke
  [[ $name =~ ^[A-Za-z0-9_.-]+$ ]] || die "not a grant name: $name"
  [ -f "$STATE_DIR/$name" ] || return 0
  kind=$(head -n 1 "$STATE_DIR/$name")
  mp=$GRANTS_DIR/$name
  if [ "$kind" = mount ] && mountpoint -q -- "$mp"; then
    if ! umount -- "$mp" 2>/dev/null; then
      mapfile -t pids < <(holders "$mp")
      if [ "${#pids[@]}" -gt 0 ]; then
        kill -TERM "${pids[@]}" 2>/dev/null || true
        sleep 2
        kill -KILL "${pids[@]}" 2>/dev/null || true
        sleep 0.2
      fi
      if ! umount -- "$mp" 2>/dev/null; then
        umount --lazy -- "$mp"
        logger -p auth.warning -t claude-sandbox-grant \
          "$name was still busy at its end and is detached lazily"
      fi
    fi
  fi
  if [ -d "$mp" ]; then rmdir -- "$mp"; else rm -f -- "$mp"; fi
  rm -f -- "$STATE_DIR/$name"
  # For a grant closed early. From the timer's own service this stops a
  # timer that has just elapsed, which is harmless.
  systemctl stop "claude-sandbox-grant-$name.timer" 2>/dev/null || true
}

list() {
  local f kind until source
  for f in "$STATE_DIR"/*; do
    [ -f "$f" ] || continue
    {
      read -r kind
      read -r until
      IFS= read -r source
    } <"$f"
    printf '%s\t%s\tuntil %s\t%s\n' "$(basename "$f")" "$kind" \
      "$(date -d "@$until" '+%H:%M:%S')" "$source"
  done
}

auto=""
if [ "${1:-}" = --auto ]; then
  auto=1
  shift
fi

case "${1:-}" in
  check)
    [ $# -eq 2 ] || die "usage: check <path>"
    [[ $2 == /* ]] || refuse "not an absolute path: $2"
    real=$(realpath -e -- "$2" 2>/dev/null) || refuse "does not resolve: $2"
    if [ ! -d "$real" ] && [ ! -f "$real" ]; then
      refuse "neither a directory nor a regular file: $real"
    fi
    policy "$real" "$(stat -c %u -- "$real")"
    echo ok
    echo "$real"
    if is_auto "$real"; then echo auto; else echo ask; fi
    ;;
  check-snapshot)
    [ $# -eq 3 ] || die "usage: check-snapshot <source> <arg>"
    snapshot_policy "$2" "$3"
    echo ok
    echo "@$2${3:+:$3}"
    if [ -n "$snap_auto" ]; then echo auto; else echo ask; fi
    ;;
  grant)
    [ $# -eq 3 ] || die "usage: grant <path> <span>"
    grant "$2" "$3"
    ;;
  snapshot)
    [ $# -eq 4 ] || die "usage: snapshot <source> <arg> <span>"
    snapshot "$2" "$3" "$4"
    ;;
  revoke)
    [ $# -eq 2 ] || die "usage: revoke <name>"
    revoke "$2"
    ;;
  list)
    list
    ;;
  *)
    die "usage: [--auto] check|check-snapshot|grant|snapshot|revoke|list ..."
    ;;
esac
