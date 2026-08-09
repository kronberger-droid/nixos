#!@bash@/bin/bash
APP_ID="ncspot_popup"
SESSION_NAME="ncspot"
JQ="@jq@/bin/jq"

window_exists() {
  niri msg -j windows | $JQ -e ".[] | select(.app_id == \"$APP_ID\")" >/dev/null 2>&1
}

await_state() {
  local want="$1"
  for _ in $(seq 1 20); do
    if [ "$want" = "open" ] && window_exists; then return 0; fi
    if [ "$want" = "closed" ] && ! window_exists; then return 0; fi
    @coreutils@/bin/sleep 0.05
  done
}

WINDOW_JSON=$(niri msg -j windows)
WINDOW_ID=$(echo "$WINDOW_JSON" | $JQ -r '.[] | select(.app_id == "'"$APP_ID"'") | .id // empty')

if [ -n "$WINDOW_ID" ]; then
  FOCUSED_APP=$(niri msg -j focused-window | $JQ -r '.app_id // empty')
  if [ "$FOCUSED_APP" = "$APP_ID" ]; then
    niri msg action close-window --id "$WINDOW_ID"
    await_state "closed"
  else
    niri msg action focus-window --id "$WINDOW_ID"
  fi
else
  # Drop a resurrectable-but-dead session of the same name so we don't
  # attach to a ghost where ncspot is no longer running.
  if @zellij@/bin/zellij list-sessions -n 2>/dev/null | grep -q "^$SESSION_NAME .*EXITED"; then
    @zellij@/bin/zellij delete-session "$SESSION_NAME" --force >/dev/null 2>&1 || true
  fi
  if @zellij@/bin/zellij list-sessions -s -n 2>/dev/null | grep -qx "$SESSION_NAME"; then
    @terminalBin@ @terminalAppIdFlag@ "$APP_ID" @terminalExecFlag@ @zellij@/bin/zellij attach "$SESSION_NAME"
  else
    @terminalBin@ @terminalAppIdFlag@ "$APP_ID" @terminalExecFlag@ @zellij@/bin/zellij -s "$SESSION_NAME" -n ncspot
  fi
  await_state "open"
fi
