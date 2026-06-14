#!/bin/bash
# Prerequisites:
#   1. Install mmx CLI:  npm install -g mmx-cli
#   2. Authenticate:     mmx auth login --api-key sk-xxxxx
#
# The script relies on 'mmx' being in PATH.
# On first run, ensure 'mmx quota' works in your terminal before using this script.

CACHE="/tmp/mmx-quota-cache.txt"
MAX_AGE=55

if [ -f "$CACHE" ] && [ -s "$CACHE" ]; then
  AGE=$(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %Sm "$CACHE" 2>/dev/null)))
  if [ "$AGE" -lt "$MAX_AGE" ]; then
    cat "$CACHE"
    exit 0
  fi
fi

OUT=$(timeout 8 mmx quota 2>/dev/null | node -e "let d=JSON.parse(require('fs').readFileSync(0,'utf8'));let g=d.model_remains.find(m=>m.model_name==='general');let ms=g.remains_time;let h=Math.floor(ms/3600000);let m=Math.round(ms%3600000/60000);console.log('API Left: '+g.current_interval_remaining_percent+'% | API Reset: '+h+'h:'+(m<10?'0':'')+m+'m')" 2>&1)
if [ -n "$OUT" ]; then
  echo "$OUT" > "$CACHE"
  echo "$OUT"
else
  [ -f "$CACHE" ] && cat "$CACHE"
fi