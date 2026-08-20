#!/bin/bash
# Syncs notes/knowledge/ (canonical) to ai_systems/.claude/knowledge/ (git copy)
# at end of agent session. This ensures Cursor agent writes are available for git commits.
# Runs as a Cursor stop hook (has Documents access via Terminal FDA).

CANONICAL="$HOME/Documents/work/notes/knowledge/"
GIT_COPY="$HOME/Documents/work/ai/ai_systems/.claude/knowledge/"

[ -d "$CANONICAL" ] && mkdir -p "$GIT_COPY" && rsync -a --delete "$CANONICAL" "$GIT_COPY"
