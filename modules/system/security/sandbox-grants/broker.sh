# One request from the sandbox, start to finish. systemd starts this per
# connection on the broker socket (Accept=yes), as the primary user, with
# the connection on stdin and stdout and the instance name as $1.
# agent-sandbox-grants.nix puts the settings in front of this text.
#
# The request is three lines: what, for how long, and why. The answer is
# lines of text whose last one starts with `granted`, `denied`, `refused`,
# `busy` or `locked`.
#
# Nothing here grants anything. This side decides whether to ask and
# carries the answer back; the mount is the root helper's, behind sudo.

say() { printf '%s\n' "$*"; }

# For a unix socket systemd names the instance <nr>-<pid>-<uid> after the
# peer, so the kernel says who is asking and the request cannot.
if [ "${1##*-}" != "$(id -u "$SANDBOX_USER")" ]; then
  say "refused: only the sandbox account asks here"
  exit 0
fi

IFS= read -r -t 5 -n 4096 target || target=""
IFS= read -r -t 5 -n 64 span || span=""
IFS= read -r -t 5 -n 1024 reason || reason=""
span=${span:-$DEFAULT_SPAN}
# The reason is the agent's own text, shown to a person about to decide.
# No control characters, and short enough that it cannot push the path
# out of the prompt.
reason=$(printf %s "$reason" | tr -d '[:cntrl:]' | cut -c1-200)

if [ -z "$target" ] || [[ $target == *[[:cntrl:]]* ]]; then
  say "refused: no path given"
  exit 0
fi
if [[ ! $span =~ ^[0-9a-zA-Z.\ ]+$ ]]; then
  say "refused: not a time span: $span"
  exit 0
fi

# One request at a time. A second prompt stacked on the first is how a
# person ends up answering the wrong one.
exec 9>"$STATE/lock"
if ! flock -n 9; then
  say "busy: another request is waiting for its answer"
  exit 0
fi

now=$(date +%s)
if [ -e "$STATE/locked" ]; then
  say "locked: $LOCKOUT_DENIALS requests were denied within the hour. Lifted with: claude-sandbox-grant reset"
  exit 0
fi
last=$(tail -n 1 "$STATE/denials" 2>/dev/null || true)
if [ -n "$last" ] && [ $((now - last)) -lt "$COOLDOWN" ]; then
  say "refused: a request was just denied, wait $((COOLDOWN - now + last))s"
  exit 0
fi

# The helper's own check, run here without root: it resolves the path and
# applies the policy, so a request that could never be granted costs
# nobody a prompt. What it prints is what the prompt shows, never the
# string the agent sent. A path this account cannot resolve is refused
# here, which keeps approval to things that can be named to the approver.
if [[ $target == @* ]]; then
  spec=${target#@}
  src=${spec%%:*}
  arg=""
  if [[ $spec == *:* ]]; then arg=${spec#*:}; fi
  if ! out=$("$HELPER" check-snapshot "$src" "$arg"); then
    say "${out:-refused}"
    exit 0
  fi
  mapfile -t checked <<<"$out"
  cmd=(snapshot "$src" "$arg" "$span")
else
  if ! out=$("$HELPER" check "$target"); then
    say "${out:-refused}"
    exit 0
  fi
  mapfile -t checked <<<"$out"
  cmd=(grant "${checked[1]}" "$span")
fi
what=${checked[1]}
mode=${checked[2]}

key=$(printf %s "$what" | sha256sum | cut -c1-16)
last=$(cat "$STATE/denied-$key" 2>/dev/null || true)
if [ -n "$last" ] && [ $((now - last)) -lt "$PATH_COOLDOWN" ]; then
  say "refused: $what was denied, wait $((PATH_COOLDOWN - now + last))s before asking for it again"
  exit 0
fi

denied() {
  local recent=0 t
  say "$now" >>"$STATE/denials"
  say "$now" >"$STATE/denied-$key"
  while read -r t; do
    if [ $((now - t)) -lt 3600 ]; then recent=$((recent + 1)); fi
  done <"$STATE/denials"
  if [ "$recent" -ge "$LOCKOUT_DENIALS" ]; then : >"$STATE/locked"; fi
  say "denied"
}

rc=0
if [ "$mode" = auto ]; then
  # Declared in the nix config as needing no answer. The wrapper behind
  # this rule passes --auto, so the helper holds it to that list.
  out=$("$SUDO" -n "$AUTO" "${cmd[@]}") || rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 3 ]; then
    say "denied: the auto-approved grant failed"
    exit 0
  fi
elif [ -n "$ASKPASS" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
  # The approval is the primary user's password, typed into a sieb panel
  # that shows the resolved path. sudo checks it, so there is no
  # passwordless way to this helper and a process that merely runs as him
  # cannot approve for him. -k: a sudo he used a minute ago in some
  # terminal must not answer this.
  say "$what for $span${reason:+ · claude says: $reason}" >"$STATE/prompt"
  rm -f "$STATE/answer" "$STATE/asked"
  out=$(SUDO_ASKPASS="$ASKPASS" "$SUDO" -k -A "$HELPER" "${cmd[@]}") || rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 3 ]; then
    # Only a deliberate no counts toward the lockout. A prompt that ran
    # out with nobody at the desk is not one.
    if [ "$(cat "$STATE/answer" 2>/dev/null || true)" = cancel ]; then
      denied
    else
      say "denied: no answer, or not the password"
    fi
    exit 0
  fi
else
  # Nobody to show a panel to: a host without a compositor, or a session
  # reached over ssh. The request waits for `claude-sandbox-grant approve`.
  id=$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')
  rm -f "$STATE/decision"
  printf '%s\n' "$id" "$now" "$what" "$reason" "${cmd[@]}" >"$STATE/pending.new"
  mv "$STATE/pending.new" "$STATE/pending"
  say "pending $id: $what for $span, waiting for: claude-sandbox-grant approve $id"
  for ((i = 0; i < QUEUE_TIMEOUT; i++)); do
    [ ! -f "$STATE/decision" ] || break
    sleep 1
  done
  rm -f "$STATE/pending"
  if [ ! -f "$STATE/decision" ]; then
    say "denied: nobody answered within $((QUEUE_TIMEOUT / 60)) minutes"
    exit 0
  fi
  mapfile -t decision <"$STATE/decision"
  rm -f "$STATE/decision"
  if [ "${decision[0]:-}" != "$id" ]; then
    say "denied: the answer was for another request"
    exit 0
  fi
  case "${decision[1]:-}" in
    granted | refused) out=$(printf '%s\n' "${decision[@]:2}") ;;
    *)
      denied
      exit 0
      ;;
  esac
fi

say "${out:-denied}"
