#!@bash@/bin/bash
if @procps@/bin/pgrep -x wl-screenrec >/dev/null 2>&1; then
  echo '{"text":"REC","class":"recording"}'
else
  echo ""
fi
