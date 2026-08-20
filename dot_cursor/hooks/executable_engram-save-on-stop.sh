#!/usr/bin/env bash
# stop hook: save key session context to Engram after agent stops
# This is a best-effort fire-and-forget; failures should not block anything
input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir_short=""
[ -n "$cwd" ] && dir_short="${cwd##*/}"

if command -v engram > /dev/null 2>&1; then
  engram note "Session $session_id completed in $dir_short" > /dev/null 2>&1
fi

exit 0
