#!/bin/bash
# Singularity — Session End Hook
# Saves session context to Obsidian vault on session end.
# Called by any provider's session-end hook.
# Usage: SINGULARITY_PROVIDER=claude ~/.singularity/hooks/session-end.sh

source "$HOME/.singularity/.env"
VAULT_PATH="${SINGULARITY_VAULT_PATH}"
DATE=$(date +%Y-%m-%d)
PROJECT=$(basename "$PWD")
SLUG=$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
PROVIDER="${SINGULARITY_PROVIDER:-unknown}"
SESSION_FILE="Sessions/${DATE}-${SLUG}.md"

# Read session data from stdin
SESSION_DATA=$(cat)

# Skip if session data is empty or trivial
if [ ${#SESSION_DATA} -lt 100 ]; then
  exit 0
fi

# Ensure directory exists
mkdir -p "$VAULT_PATH/Sessions"

# If file already exists (multiple sessions same day, same project), append a counter
if [ -f "$VAULT_PATH/$SESSION_FILE" ]; then
  COUNTER=2
  while [ -f "$VAULT_PATH/Sessions/${DATE}-${SLUG}-${COUNTER}.md" ]; do
    COUNTER=$((COUNTER + 1))
  done
  SESSION_FILE="Sessions/${DATE}-${SLUG}-${COUNTER}.md"
fi

cat > "$VAULT_PATH/$SESSION_FILE" << EOF
---
date: $DATE
project: $PROJECT
provider: $PROVIDER
tags: [session, $SLUG]
---

# Session: $PROJECT ($DATE)

## Raw Context
$SESSION_DATA
EOF
