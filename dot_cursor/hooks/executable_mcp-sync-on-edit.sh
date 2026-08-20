#!/usr/bin/env bash
# afterFileEdit hook: trigger MCP credential sync when ~/.cursor/mcp.json is edited
input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // empty')

case "$file_path" in
  */mcp.json)
    if [ "$file_path" = "$HOME/.cursor/mcp.json" ]; then
      "$HOME/.cursor/scripts/mcp-sync.sh" 2>&1
    fi
    ;;
esac

exit 0
