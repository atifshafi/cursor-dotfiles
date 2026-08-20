#!/usr/bin/env bash
set -euo pipefail
LOG="$HOME/.local/share/chezmoi/.chezmoi-sync.log"

{
  echo "--- sync started $(date) ---"

  # 1. Re-read local changes into source state
  chezmoi re-add

  # 2. Reconcile deletions (skip symlinks -- they may be dead by design)
  chezmoi managed --include=files --path-style=absolute | while read -r managed_path; do
    if [ ! -L "$managed_path" ] && [ ! -e "$managed_path" ]; then
      echo "Forgetting removed file: $managed_path"
      chezmoi forget "$managed_path"
    fi
  done

  # 3. Pull remote changes first (rebase to avoid merge commits)
  chezmoi git -- pull --rebase --autostash || {
    echo "ERROR: pull --rebase failed. Manual resolution needed."
    exit 1
  }

  # 4. Stage and commit (exit gracefully if nothing changed)
  chezmoi git -- add -A
  chezmoi git -- diff --cached --quiet && {
    echo "Nothing to sync."
    exit 0
  }
  chezmoi git -- commit -m "auto-sync $(date +%F)"

  # 5. Push
  chezmoi git -- push || {
    echo "ERROR: push failed after commit."
    exit 1
  }

  echo "--- sync complete ---"
} >> "$LOG" 2>&1
