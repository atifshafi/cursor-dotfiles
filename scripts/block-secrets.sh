#!/usr/bin/env bash
# Block secrets.yaml from being committed
if git diff --cached --name-only | grep -q 'secrets.yaml'; then
  echo "ERROR: secrets.yaml is staged for commit! Remove it with: git reset HEAD .chezmoidata/secrets.yaml"
  exit 1
fi
exit 0
