#!@bash@/bin/bash

if niri msg -j windows 2>/dev/null | @jq@/bin/jq -e '.[] | select(.app_id == "scratchpad")' >/dev/null 2>&1; then
  echo '{"text":"\uf489","alt":"open","tooltip":"Scratchpad open","class":"open"}'
else
  echo '{"text":"\uf489","alt":"closed","tooltip":"Scratchpad closed","class":"closed"}'
fi
