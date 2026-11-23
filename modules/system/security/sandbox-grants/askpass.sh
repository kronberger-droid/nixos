# sudo's askpass for a grant: the password prompt as a sieb-pinentry panel
# that says what is being granted. agent-sandbox-grants.nix puts the
# settings in front of this text.
#
# The text comes from a file the broker wrote, since sudo hands an askpass
# program nothing but its own prompt string. sudo runs this again after a
# wrong password, which `asked` turns into the panel's error line.
#
# The panel has no rows, so there is nothing a stray keystroke could pick.
# Enter on the empty field and Escape both mean no.

desc=$(head -c 600 "$STATE/prompt" 2>/dev/null | tr -d '[:cntrl:]' || true)
# Assuan reads % as the start of an escape.
desc=${desc//%/%25}

ask=("SETTITLE Sandbox grant" "SETPROMPT Grant" "SETDESC $desc")
if [ -e "$STATE/asked" ]; then ask+=("SETERROR Not the password"); fi
: >"$STATE/asked"

rc=0
reply=$(printf '%s\n' "${ask[@]}" GETPIN BYE | timeout "$PROMPT_TIMEOUT" "$PINENTRY") || rc=$?
if [ "$rc" -eq 124 ]; then
  echo timeout >"$STATE/answer"
  exit 1
fi

pin=""
got=""
while IFS= read -r line; do
  case $line in
    "D "*)
      pin+=${line#D }
      got=1
      ;;
    "ERR 83886179"*) break ;;
  esac
done < <(printf '%s\n' "$reply")

if [ -z "$got" ]; then
  echo cancel >"$STATE/answer"
  exit 1
fi

pin=${pin//%0D/$'\r'}
pin=${pin//%0A/$'\n'}
pin=${pin//%25/%}
printf '%s\n' "$pin"
