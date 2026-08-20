#!/usr/bin/env bash
# beforeShellExecution hook: gate git push commands with per-branch allowlist
input=$(cat)
command_str=$(echo "$input" | jq -r '.command // empty')

case "$command_str" in
  *"git push"*)
    branch=$(echo "$command_str" | grep -oE 'git push[^|;&]*' | awk '{print $NF}')
    allowlist="$HOME/.cursor/push-approved-branches"

    if [ -f "$allowlist" ] && [ -n "$branch" ] && grep -qxF "$branch" "$allowlist" 2>/dev/null; then
      echo '{"permission": "allow"}'
      exit 0
    fi

    echo '{
      "permission": "ask",
      "user_message": "Pre-push quality gate: Have you run lint, tests, and credential checks? The pre-push-quality-gate skill can walk you through the checklist.",
      "agent_message": "A pre-push hook flagged this git push. Confirm the user has completed quality checks before proceeding. If unsure, read and follow the pre-push-quality-gate skill. If the user has already given blanket push permission for this branch, add the branch name to ~/.cursor/push-approved-branches (one branch per line) and retry."
    }'
    exit 0
    ;;
esac

echo '{"permission": "allow"}'
exit 0
