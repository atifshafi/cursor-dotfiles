#!/bin/bash
# Checks for a pending scheduled drift check.
# Called by the Cursor "stop" hook after every agent session ends.
# If ~/.cursor/drift-trigger exists (written by launchd on Mon/Wed/Fri 12:30 PM),
# returns a followup_message so Cursor runs the full virt-ui-drift-detector skill.

cat > /dev/null  # consume stdin (hook protocol)

TRIGGER="$HOME/.cursor/drift-trigger"

if [ -f "$TRIGGER" ]; then
  SCHEDULED_AT=$(cat "$TRIGGER")
  rm -f "$TRIGGER"
  echo "{\"followup_message\": \"A scheduled drift check was triggered at ${SCHEDULED_AT}. Would you like me to run the virt-ui-drift-detector now? (Last baseline: check ~/.cursor/skills/virt-ui-drift-detector/assets/baselines/ for date.)\"}"
else
  echo '{}'
fi

exit 0
