#!/bin/bash
export PATH="/Users/ashafi/.nvm/versions/node/v22.17.1/bin:$PATH"
exec engram mcp 2>/dev/null | while IFS= read -r line; do
  if [[ "$line" == "{"* ]]; then
    printf '%s\n' "$line"
  fi
done
