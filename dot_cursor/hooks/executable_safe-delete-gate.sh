#!/bin/bash
input=$(cat)
command=$(echo "$input" | /opt/homebrew/bin/jq -r '.command // empty')

if [ -z "$command" ]; then
  echo '{"permission":"allow"}'
  exit 0
fi

PROTECTED_PATHS=(
  "/Users/ashafi/Documents/work"
  "/Users/ashafi/Documents"
  "/Users/ashafi/Library"
  "/Users/ashafi/.cursor"
  "/Users/ashafi/.ssh"
  "/Users/ashafi/.kube"
  "/Users/ashafi/.engram"
)

resolve_and_check() {
  local target="$1"
  
  target="${target/#\~//Users/ashafi}"
  target="${target/#\$HOME//Users/ashafi}"
  
  if [ -L "$target" ]; then
    local resolved=$(readlink -f "$target" 2>/dev/null || readlink "$target" 2>/dev/null)
    if [ -n "$resolved" ]; then
      for protected in "${PROTECTED_PATHS[@]}"; do
        if [[ "$resolved" == "$protected" || "$resolved" == "$protected/"* ]]; then
          echo "$resolved"
          return 1
        fi
      done
    fi
  fi
  
  if [ -e "$target" ]; then
    local resolved=$(readlink -f "$target" 2>/dev/null || echo "$target")
    for protected in "${PROTECTED_PATHS[@]}"; do
      if [[ "$resolved" == "$protected" || "$resolved" == "$protected/"* ]]; then
        if [[ "$command" == *"$protected"* ]]; then
          echo "$resolved"
          return 0
        else
          echo "$resolved"
          return 1
        fi
      fi
    done
  fi
  
  return 0
}

extract_rm_targets() {
  local cmd="$1"
  echo "$cmd" | grep -oE '(rm|rmdir)\s+[^|;&]+' | sed 's/^rm\s*//;s/^rmdir\s*//' | tr ' ' '\n' | grep -v '^-' | grep -v '^$'
}

if echo "$command" | grep -qE '\brm\b|\brmdir\b'; then
  targets=$(extract_rm_targets "$command")
  
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    
    target="${target/#\~//Users/ashafi}"
    target="${target/#\$HOME//Users/ashafi}"
    
    if [ -L "$target" ]; then
      resolved=$(readlink -f "$target" 2>/dev/null || readlink "$target" 2>/dev/null)
      for protected in "${PROTECTED_PATHS[@]}"; do
        if [[ "$resolved" == "$protected" || "$resolved" == "$protected/"* ]]; then
          msg="BLOCKED: '$target' is a SYMLINK pointing to '$resolved' (protected path). Deleting it would destroy real data."
          echo "{\"permission\":\"deny\",\"user_message\":\"$msg\",\"agent_message\":\"$msg\"}"
          exit 0
        fi
      done
    fi

    for protected in "${PROTECTED_PATHS[@]}"; do
      if [[ "$target" == "$protected" || "$target" == "$protected/" ]]; then
        msg="BLOCKED: Refusing to delete '$target' -- this is a protected path root."
        echo "{\"permission\":\"deny\",\"user_message\":\"$msg\",\"agent_message\":\"$msg\"}"
        exit 0
      fi
    done
    
    if [[ "$target" == "/" || "$target" == "/Users" || "$target" == "/Users/ashafi" ]]; then
      msg="BLOCKED: Refusing to delete '$target' -- this is a critical system path."
      echo "{\"permission\":\"deny\",\"user_message\":\"$msg\",\"agent_message\":\"$msg\"}"
      exit 0
    fi
    
  done <<< "$targets"
fi

echo '{"permission":"allow"}'
exit 0
